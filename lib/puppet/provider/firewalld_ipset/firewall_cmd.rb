require 'puppet'
require File.join(File.dirname(__FILE__), '..', 'firewalld.rb')

Puppet::Type.type(:firewalld_ipset).provide(
  :firewall_cmd,
  :parent => Puppet::Provider::Firewalld
) do
  desc "Interact with firewall-cmd"

  def exists?
    execute_firewall_cmd(['--get-ipsets'], nil).split(" ").include?(@resource[:name])
  end

  def create
    args = []
    args << ["--new-ipset=#{@resource[:name]}"]
    args << ["--type=#{@resource[:type]}"]
    args << ["--option=#{@resource[:options].map { |a,b| "#{a}=#{b}" }.join(',')}"] if @resource[:options]
    execute_firewall_cmd(args.flatten, nil)
    add_entries_from_file(@resource[:entries])
  end

  def entries
    execute_firewall_cmd(["--ipset=#{@resource[:name]}", "--get-entries"], nil).split("\n").sort
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
