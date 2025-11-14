{ ... }:
{
  services.blocky = {
    enable = true;
    settings = {
      upstreams.groups.default = [
        "https://one.one.one.one/dns-query"
        "8.8.8.8"
      ];
      blocking.denylists.ads = [
        "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/pro.txt"
        # "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
      ];
    };
  };
}
