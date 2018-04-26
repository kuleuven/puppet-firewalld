require_relative '../../puppet_x/firewalld/property/positive_integer'

Puppet::Type.newtype(:firewalld_ipset) do

  @doc =%q{
    Configure IPsets in Firewalld
    
    Example:
    
        firewalld_ipset {'internal net':
            ensure   => 'present',
            type     => 'hash:net',
            family   => 'inet',
            entries  => ['192.168.0.0/24']
        }
  }
  
  ensurable do
    defaultvalues
    defaultto :present
  end
  
  newparam(:name, :namevar => true) do
    desc "Name of the IPset"
    validate do |val|
      raise Puppet::Error, "IPset name must be a word with no spaces" unless val =~ /^[\w-]+$/
    end
  end
  
  newparam(:type) do
    desc "Type of the ipset (default: hash:ip)"
    defaultto "hash:ip"
    newvalues(:'bitmap:ip', :'bitmap:ip,mac', :'bitmap:port', :'hash:ip', :'hash:ip,mark', :'hash:ip,port', :'hash:ip,port,ip', :'hash:ip,port,net', :'hash:mac', :'hash:net', :'hash:net,iface', :'hash:net,net', :'hash:net,port', :'hash:net,port,net', :'list:set')
  end

  newparam(:options) do
    desc "Hash of options for the IPset, eg { 'family' => 'inet6' }"
    validate do |val|
      raise Puppet::Error, "options must be a hash" unless val.is_a?(Hash)
    end
  end

  newproperty(:entries, :array_matching => :all) do
    desc "Array of ipset entries"
    def insync?(is)
      should.sort == is
    end

    def change_to_s(current, desire)
      if @resource.value(:keep_in_sync)
        "removing entries from ipset #{(current - desire).sort.inspect},
         adding in ipset entries #{(desire - current).sort.inspect}"
      else
        "adding in ipset entries #{(desire - current).sort.inspect}"
      end
    end

    munge do |value|
      value.gsub('/32', '')
    end
  end

  newproperty(:family) do
    desc "Protocol family of the IPSet"
    newvalues(:inet6, :inet)
  end

  newproperty(:hashsize, :parent => PuppetX::Firewalld::Property::PositiveInteger) do
    desc "Initial hash size of the IPSet"
  end

  newproperty(:maxelem, :parent => PuppetX::Firewalld::Property::PositiveInteger) do
    desc "Maximal number of elements that can be stored in the set"
  end

  newproperty(:timeout, :parent => PuppetX::Firewalld::Property::PositiveInteger) do
    desc "Timeout in seconds before entries expiry"
  end

  newparam(:manage_entries, :parent => Puppet::Parameter::Boolean) do
    desc "Should we manage entries in this ipset or leave another process manage those entries"
    defaultto true
  end

  validate do
    if not self[:manage_entries] and self[:entries]
      raise(Puppet::Error, "Ipset should not declare entries if it doesn't manage entries")
    end
  end

end
  
