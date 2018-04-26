require 'spec_helper'

describe Puppet::Type.type(:firewalld_ipset) do

  before do
    Puppet::Provider::Firewalld.any_instance.stubs(:state).returns(:true)
    tempfile = stub('tempfile', :class => Tempfile,
                  :write => true,
                  :flush => true,
                  :close! => true,
                  :close => true,
                  :path => '/tmp/ipset-rspec'
                 )
      Tempfile.stubs(:new).returns(tempfile)
  end

  describe "type" do
    context 'with no params' do
      describe 'when validating attributes' do
        [  
          :name, :type, :options
        ].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:param)
          end
        end
      
  
        [  
          :entries
        ].each do |param|
          it "should have a #{param} parameter" do
            expect(described_class.attrtype(param)).to eq(:property)
          end
        end
      end
    end
    it 'raises an error if wrong name' do
      expect do described_class.new(
        name: 'white black',
        type: 'hash:net',
      ) end.to raise_error(/IPset name must be a word with no spaces/)
    end
    it 'accept - in name' do
      expect do described_class.new(
        name: 'white-blue',
        type: 'hash:net'
      ) end.to_not raise_error
    end
  end


  ## Provider tests for the firewalld_zone type
  #
  describe "provider" do

    let(:resource) {
      described_class.new(
        :name => 'whitelist', 
        :entries    => ['192.168.2.2', '10.72.1.100'])
    }
    let(:provider) {
      resource.provider
    }

    it "should create" do
      provider.expects(:execute_firewall_cmd).with(['--new-ipset=whitelist', '--type=hash:ip'], nil)
      provider.expects(:execute_firewall_cmd).with(["--ipset=whitelist", "--add-entries-from-file=/tmp/ipset-rspec"], nil)
      provider.create
    end

    it "should remove" do
      provider.expects(:execute_firewall_cmd).with(['--delete-ipset=whitelist'], nil)
      provider.destroy
    end

    it "should set entries" do
      provider.expects(:entries).returns([]).at_least_once()
      provider.expects(:execute_firewall_cmd).with(["--ipset=whitelist", "--add-entries-from-file=/tmp/ipset-rspec"], nil)
      provider.expects(:execute_firewall_cmd).with(["--ipset=whitelist", "--remove-entries-from-file=/tmp/ipset-rspec"], nil)
      provider.entries=(['192.168.2.2', '10.72.1.100'])
    end

    it "should remove unconfigured entries" do
      provider.expects(:entries).returns(['10.9.9.9', '10.8.8.8', '10.72.1.100']).at_least_once()
      provider.expects(:execute_firewall_cmd).with(["--ipset=whitelist", "--add-entries-from-file=/tmp/ipset-rspec"], nil)
      provider.expects(:execute_firewall_cmd).with(["--ipset=whitelist", "--remove-entries-from-file=/tmp/ipset-rspec"], nil)
      provider.entries=(['192.168.2.2', '10.72.1.100'])
    end
  end
  context 'change in ipset members' do
    let(:resource) do
      Puppet::Type.type(:firewalld_ipset).new(
        name: 'white',
        type: 'hash:net',
        entries: ['8.8.8.8/32', '9.9.9.9']
      )
    end

    it 'removes /32 in set members' do
      expect(resource[:entries]).to eq ['8.8.8.8', '9.9.9.9']
    end
  end

  context 'validation when not managing ipset entries ' do
    it 'raises an error if wrong type' do
      expect do Puppet::Type.type(:firewalld_ipset).new(
        name: 'white',
        type: 'hash:net',
        manage_entries: false,
        entries: ['8.8.8.8/32', '9.9.9.9']
      ) end.to raise_error(/Ipset should not declare entries if it doesn't manage entries/)
    end
  end
end
