{ ... }:
{
  # networking.nameservers = [ "127.0.0.1" ];
  services.blocky = {
    enable = true;
    settings = {
      bootstrapDns = {
        upstream = "https://one.one.one.one/dns-query";
        ips = [
          "1.1.1.1"
          "1.0.0.1"
        ];
      };
      upstreams.groups.default = [
        "https://dns.quad9.net/dns-query"
        "https://one.one.one.one/dns-query"
        "https://dns.google/dns-query"
      ];
      blocking = {
        denylists.ads = [
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/pro.txt"
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
        ];
        clientGroupsBlock.default = [ "ads" ];
      };
      ports.http = "4000";
      prometheus.enable = true;
    };
  };
}
