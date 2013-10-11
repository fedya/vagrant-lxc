module Vagrant
  module LXC
    module Action
        class FetchIpWithLxcAttach
          # Include this so we can use `Subprocess` more easily.
          include Vagrant::Util::Retryable

          def initialize(app, env)
            @app    = app
            @logger = Log4r::Logger.new("vagrant::lxc::action::fetch_ip_with_lxc_attach")
          end

          def call(env)
            env[:machine_ip] ||= assigned_ip(env)
          rescue LXC::Errors::NamespacesNotSupported
            @logger.info 'The `lxc-attach` command available does not support the --namespaces parameter, falling back to dnsmasq leases to fetch container ip'
          ensure
            @app.call(env)
          end

          def assigned_ip(env)
            driver = env[:machine].provider.driver
            ip = ''
            ip6 = true
            retryable(:on => LXC::Errors::ExecuteError, :tries => 10, :sleep => 3) do
              unless ip = get_container_ip_from_ip_addr(driver, ip6 = !ip6)
                # retry
                raise LXC::Errors::ExecuteError, :command => "lxc-attach"
              end
            end
            ip
          end

          # From: https://github.com/lxc/lxc/blob/staging/src/python-lxc/lxc/__init__.py#L371-L385
          def get_container_ip_from_ip_addr(driver, ip6 = false)
            output =  if ip6
                        driver.attach '/sbin/ip', '-6', 'addr', 'show', 'eth0', namespaces: 'network'
                      else
                        driver.attach '/sbin/ip', '-4', 'addr', 'show', 'scope', 'global', 'eth0', namespaces: 'network'
                      end
            # if output =~ /^\s+inet ([0-9.]+)\/[0-9]+\s+/
            if output =~ /^\s+inet6?\s+([\w:\.]+)\/[0-9]+/
              return $1.to_s
            end
          end
        end
      end
    end
  end
