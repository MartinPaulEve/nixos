# Email client.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    thunderbird        # Email / calendar client
  ];
}
