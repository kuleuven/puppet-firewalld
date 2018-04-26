require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_ipset).provide(
  :firewall_cmd,
  :parent => Puppet::Provider::Firewalld
) do
  desc "Interact with firewall-cmd"

  mk_resource_methods

  def self.instances
    ipset_ids = execute_firewall_cmd(['--get-ipsets'], nil).split(" ")
    ipset_ids.collect do |ipset_id|
      ipset_raw = execute_firewall_cmd(["--info-ipset=#{ipset_id}"], nil)
      raw_options = ipset_raw.match(/options: (.*)/)
      options = {}
      if raw_options
        raw_options[1].split(' ').each { |v|
          k, v = v.split('=')
          options[k.to_sym] = v
        }
      end
      new(
        ensure: :present,
        name: ipset_id,
        type: ipset_raw.match(/type: (.*)/)[1],
        **options
      )
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if (resource = resources[prov.name])
        resource.provider = prov
      end
    end
  end

  def exists?
    execute_firewall_cmd(['--get-ipsets'], nil).split(" ").include?(@resource[:name])
  end

  def create
    args = []
    args << ["--new-ipset=#{@resource[:name]}"]
    args << ["--type=#{@resource[:type]}"]
    options = {
      :family => @resource[:family],
      :hashsize => @resource[:hashsize],
      :maxelem => @resource[:maxelem],
      :timeout => @resource[:timeout]
    }
    options = options.merge(@resource[:options]) if @resource[:options]
    options.each do |option_name, value|
      if value
        args << ["--option=#{option_name}=#{value}"]
      end
    end
    execute_firewall_cmd(args.flatten, nil)
    if @resource[:manage_entries]
      add_entries_from_file(@resource[:entries])
    end
  end

  %i[type maxelem family hashsize timeout].each do |method|
    define_method("#{method}=") do |should|
      info("Destroying and creating ipset #{@resource[:name]}")
      destroy
      create
      @property_hash[method] = should
    end
  end

  def entries
    if @resource[:manage_entries]
      execute_firewall_cmd(["--ipset=#{@resource[:name]}", "--get-entries"], nil).split("\n").sort
    else
      @resource[:entries]
    end
  end

  def add_entries_from_file(entries)
    f = Tempfile.new('ipset')
    entries.each { |e| f.write(e+"\n") }
    f.close
    execute_firewall_cmd(["--ipset=#{@resource[:name]}", "--add-entries-from-file=#{f.path}"], nil)
  end

  def remove_entries_from_file(entry)
    f = Tempfile.new('ipset')
    entries.each { |e| f.write(e+"\n") }
    f.close
    execute_firewall_cmd(["--ipset=#{@resource[:name]}", "--remove-entries-from-file=#{f.path}"], nil)
  end

  def entries=(should_entries)
    unless @resource[:manage_entries]
      debug("Not managing entries for ipset #{@resource[:name]}")
      return
    end
    cur_entries = entries
    delete_entries = cur_entries-should_entries
    add_entries = should_entries-cur_entries
    if delete_entries
      remove_entries_from_file(delete_entries)
    end
    if add_entries
      add_entries_from_file(add_entries)
    end
  end

  def destroy
    execute_firewall_cmd(["--delete-ipset=#{@resource[:name]}"], nil)
  end
end
