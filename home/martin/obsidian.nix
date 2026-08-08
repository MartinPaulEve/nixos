# Declaratively installs a pinned set of Obsidian community plugins into the
# MESH "commons-docs" vault.
#
# Why this is an activation script rather than the Home Manager `programs.obsidian`
# module: that module places every file with `home.file`, which can only write
# under $HOME, and it links each plugin as a symlink into the Nix store. This
# vault lives on a Parallels shared folder (/mnt/psf/Home/..., the Mac host's
# home directory), which is *outside* $HOME and is also readable from macOS —
# where /nix/store does not exist, so store symlinks would dangle. So instead we
# build each plugin as a Nix package (pinned by version + hash) and *copy* the
# real files into the vault, giving plain files that work from either OS.
#
# The vault's `.obsidian/` is gitignored (see the vault's .gitignore), so these
# plugins are not carried by the Obsidian Git plugin's sync; each machine
# installs its own copy. That is exactly why pinning them here is worthwhile.
#
# Updating a plugin: bump its `version` and refresh the three hashes with
#   nix store prefetch-file https://github.com/<repo>/releases/download/<ver>/<file>
{ lib, pkgs, ... }:

let
  # Vault root on the Parallels share. If the share is not mounted (e.g. the
  # x86 QEMU test VM), the activation script below detects the missing
  # directory and skips, so this stays harmless on other hosts.
  vault = "/mnt/psf/Home/Documents/Programming/MESH/commons-docs";

  # One release asset (main.js / manifest.json / styles.css) fetched from the
  # plugin's GitHub release by its pinned tag.
  fetchAsset =
    { repo, version, file, hash }:
    pkgs.fetchurl {
      url = "https://github.com/${repo}/releases/download/${version}/${file}";
      inherit hash;
    };

  # Assemble a plugin's directory: the two required files plus styles.css when
  # the plugin ships one (Force note view mode does not).
  buildPlugin =
    p:
    pkgs.runCommandLocal "obsidian-plugin-${p.id}-${p.version}" { } ''
      mkdir -p "$out"
      cp ${fetchAsset { inherit (p) repo version; file = "main.js"; hash = p.mainHash; }} "$out/main.js"
      cp ${fetchAsset { inherit (p) repo version; file = "manifest.json"; hash = p.manifestHash; }} "$out/manifest.json"
      ${lib.optionalString (p ? stylesHash)
        ''cp ${fetchAsset { inherit (p) repo version; file = "styles.css"; hash = p.stylesHash; }} "$out/styles.css"''}
    '';

  # The requested plugin set. `id` is the plugin's manifest id and becomes both
  # its directory name under .obsidian/plugins/ and its entry in
  # community-plugins.json.
  plugins = [
    {
      # Git — vault syncing
      pname = "obsidian-git";
      id = "obsidian-git";
      version = "2.38.6";
      repo = "Vinzent03/obsidian-git";
      mainHash = "sha256-Ma2J09lzy1UgZH1Sf1DYwj/NQhdnaDYXQaVDr1bVYoc=";
      manifestHash = "sha256-Zzke+oQJPVYBH0N2T/TxyEbditUrHx39AQq2KLIXwqM=";
      stylesHash = "sha256-9auT9NW03RvR5XeGTFx5CH9639RIrDRuBInlhHzmki0=";
    }
    {
      # Tasks — task management
      pname = "obsidian-tasks";
      id = "obsidian-tasks-plugin";
      version = "8.3.0";
      repo = "obsidian-tasks-group/obsidian-tasks";
      mainHash = "sha256-FwrAr0FggS/mxUErlhsiIql8VCOtl4pTgQnG0zIfD1I=";
      manifestHash = "sha256-y0LVY7vNX+VRABesA11wEwX8YGjK/YU4JX5UehZ/ljc=";
      stylesHash = "sha256-2thMf5im6Q2Aruu1xlvnSb4xLwOEK1Ho9qAx6yLsnOI=";
    }
    {
      # Templater — note templates (meetings / people / projects)
      pname = "templater";
      id = "templater-obsidian";
      version = "2.25.0";
      repo = "SilentVoid13/Templater";
      mainHash = "sha256-ail5DorTuz3lvMc4FYjyAJOy2+zB/yfYpdftP867304=";
      manifestHash = "sha256-dZhRiPrItRjuu3kTcKJNrhokdszjkS3kcJd4294BceQ=";
      stylesHash = "sha256-65QGO+YCZ585fj41/Lf2pLAn2oLhfCE7tEomfGtF2N4=";
    }
    {
      # Dataview — automatic queries
      pname = "dataview";
      id = "dataview";
      version = "0.5.70";
      repo = "blacksmithgu/obsidian-dataview";
      mainHash = "sha256-a7HPcBCvrYMOc1dfyg4r+9MnnFYuPZ0k8tL0UWHrfQA=";
      manifestHash = "sha256-kjXbRxEtqBuFWRx57LmuJXTl5yIHBW6XZHL5BhYoYYU=";
      stylesHash = "sha256-MwbdkDLgD5ibpyM6N/0lW8TT9DQM7mYXYulS8/aqHek=";
    }
    {
      # Multi-Column Markdown — column layouts (the ! Projects Summary page)
      pname = "multi-column-markdown";
      id = "multi-column-markdown";
      version = "0.9.1";
      repo = "ckRobinson/multi-column-markdown";
      mainHash = "sha256-i9k7J6HEBxT20SuWrYpZ9y4eiNMH4nyXVMfnfTGQmM4=";
      manifestHash = "sha256-Wx6O+uI0UztMhW/e/dggqD5Wwiegwr8dFc21lus+aaY=";
      stylesHash = "sha256-NqAcWZ099k287Rsh37wO8NDlNDEEn5JTvJkuwnpz16U=";
    }
    {
      # Force note view mode — force reading/preview mode (ships no styles.css)
      pname = "force-view-mode";
      id = "obsidian-view-mode-by-frontmatter";
      version = "1.2.2";
      repo = "bwydoogh/obsidian-force-view-mode-of-note";
      mainHash = "sha256-fDLKOhmH11JMr5/No45iqoY8qPd1QRAOX57ALqM5rGE=";
      manifestHash = "sha256-+ObNu5gRzQ8yE8gXN/TaZZCd5Ii1feWVZWGrDyPYC7E=";
    }
    {
      # Outliner — better list editing
      pname = "obsidian-outliner";
      id = "obsidian-outliner";
      version = "4.10.2";
      repo = "vslinko/obsidian-outliner";
      mainHash = "sha256-PVvGNNMEXq1N+XR9B6tR8W2XIvRgH5/uJ+DH/pgo+zM=";
      manifestHash = "sha256-J3qIh+uVnMekrgR2CEIRU7NZvfRRwtZsqrkcNcqYuT8=";
      stylesHash = "sha256-eSKiZIg4lOafIsN/VJdE99RtHekm/IAqpOlMdc0vvOs=";
    }
    {
      # Excalidraw — diagrams
      pname = "obsidian-excalidraw";
      id = "obsidian-excalidraw-plugin";
      version = "2.26.4";
      repo = "zsviczian/obsidian-excalidraw-plugin";
      mainHash = "sha256-sm8/yM+jnP7+jBHILkP4Cv3GQtjKTU7OO92Bf3LUz1o=";
      manifestHash = "sha256-9rgX2uovohBmcaYtcjbNyNgG9SRl8f86tTQyMcAgtwM=";
      stylesHash = "sha256-YVtWDFGTsspO8/8YRNKAeRO8UcQDM8ef3QioQLDEJzU=";
    }
    {
      # Auto Link Title — fetch titles for pasted URLs
      pname = "auto-link-title";
      id = "obsidian-auto-link-title";
      version = "1.5.5";
      repo = "zolrath/obsidian-auto-link-title";
      mainHash = "sha256-6ydJi/0F3Fw4R90HL1Ve1MAq7OJEUQQsLtsl/JYfOL4=";
      manifestHash = "sha256-IZFsjI+hmW04/HnmBkth9BxrNNXU6t2vNvGEMrP0mhE=";
      stylesHash = "sha256-BA2Zx4es+Q26Q3TCG2dBfd5DrMWe1KubzuUQv7xFCLI=";
    }
  ];

  built = map (p: {
    inherit (p) id;
    path = buildPlugin p;
  }) plugins;

  # "<id> <store-path>" per line, consumed by the activation loop. Ids and store
  # paths never contain spaces, so a space separator is safe.
  pluginList = pkgs.writeText "obsidian-plugin-list" (
    lib.concatMapStringsSep "\n" (b: "${b.id} ${b.path}") built + "\n"
  );

  # The ids we want listed as enabled in community-plugins.json.
  enabledFile = pkgs.writeText "obsidian-community-plugins.json" (
    builtins.toJSON (map (b: b.id) built)
  );
in
{
  home.activation.obsidianPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    vault="${vault}"
    if [ ! -d "$vault/.obsidian" ]; then
      echo "Obsidian vault $vault/.obsidian not found (share not mounted?); skipping plugin sync" >&2
    else
      (
        set -e
        pluginsDir="$vault/.obsidian/plugins"
        $DRY_RUN_CMD mkdir -p "$pluginsDir"

        # Replace each Nix-managed plugin directory with its pinned build. We own
        # these directories, so a clean rm/copy keeps them exactly matching the
        # config; plugins the user installs by hand under other ids are untouched.
        while read -r id src; do
          [ -z "$id" ] && continue
          $DRY_RUN_CMD rm -rf "$pluginsDir/$id"
          $DRY_RUN_CMD mkdir -p "$pluginsDir/$id"
          $DRY_RUN_CMD cp -f "$src"/* "$pluginsDir/$id/"
          $DRY_RUN_CMD chmod -R u+w "$pluginsDir/$id"
        done < ${pluginList}

        # Enable them: union our ids into community-plugins.json, preserving any
        # the user enabled by hand. Written afresh if the file does not exist yet.
        cpj="$vault/.obsidian/community-plugins.json"
        if [ -f "$cpj" ]; then
          tmp="$(mktemp)"
          ${lib.getExe pkgs.jq} -s '(.[0] + .[1]) | unique' "$cpj" "${enabledFile}" > "$tmp"
          $DRY_RUN_CMD install -m644 "$tmp" "$cpj"
          rm -f "$tmp"
        else
          $DRY_RUN_CMD install -D -m644 "${enabledFile}" "$cpj"
        fi
      ) || echo "Obsidian plugin sync failed" >&2
    fi
  '';
}
