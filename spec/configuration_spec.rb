require 'spec_helper'

describe Thunder::Configuration do

  its(:location){ should eq(subject.class.default_location) }
  its(:scope){ should eq(:default) }

  context '.default_location' do
    subject{ described_class }

    it 'returns ~/.thunder/config' do
      expect(subject.default_location).to eq(File.join(ENV['HOME'].to_s, '.thunder/config'))
    end
  end

  context '#empty_configuration' do
    it 'returns a hash of default values set to nil' do
      expect(subject.empty_configuration).to eq(aws_access_key_id:     nil,
                                                aws_secret_access_key: nil,
                                                connection_options:    nil,
                                                openstack_api_key:     nil,
                                                openstack_auth_url:    nil,
                                                openstack_tenant:      nil,
                                                openstack_username:    nil,
                                                region:                nil)
    end
  end

  context '#update' do
    it 'updates the internal attributes in place' do
      subject.populate!(default: {})
      expect(subject[:foo]).to be_nil
      subject.update(foo: 'bar')
      expect(subject[:foo]).to eq('bar')
    end
  end

  context '#to_hash' do
    it 'returns a duplicate of the current scope' do
      subject.populate!(default: { foo: 'bar' }, extra: { baz: 'qix' })
      expect(subject.to_hash).to eq(foo: 'bar')
    end
  end

  context '#[]' do
    it 'allows indifferent hash access to the current scope' do
      subject.populate!(default: { foo: 'bar' })
      expect(subject[:foo]).to eq('bar')
      expect(subject['foo']).to eq('bar')
    end
  end

  context '#scoped_access' do
    subject{ described_class.new(scope: example_scope) }

    before{ subject.populate!(default: { foo: 'bar' })  }

    context 'existing scope' do
      let(:example_scope){ :default }

      it 'returns nested attributes from the current scope' do
        expect(subject.scoped_access).to eq(foo: 'bar')
      end
    end

    context 'nonexistent scope' do
      let(:example_scope){ :extra }

      it 'returns empty configuration if the current scope does not exist' do
        expect(subject.scoped_access).to be_a(Hash)
        expect(subject.scoped_access).to_not be_empty
      end
    end
  end

  context '#populate!' do
    it 'populates the internal hash and returns self for chaining' do
      expect(subject).to receive(:read_from_disk).and_return(default: { foo: 'bar' })
      expect(subject.populate!).to be(subject)
      expect(subject[:foo]).to eq('bar')
    end
  end

  context '#internal_with_placeholders' do
    it 'adds missing attributes with a null value' do
      subject.populate!(default: { aws_access_key_id: 'foo' })
      subject.internal_with_placeholders.each_pair do |_, scope|
        expect(subject.all_options.all?{ |opt| scope.key? opt }).to be_true
      end
      expect(subject.internal_with_placeholders[:default][:aws_access_key_id]).to eq('foo')
    end
  end

  context '#read_from_disk' do
    let(:example_config){ File.expand_path('../tmp/thunder.yaml', __FILE__) }

    subject{ described_class.new(location: example_config) }

    around(:each) do |example|
      FileUtils.mkdir_p File.dirname(example_config)
      File.open(example_config, 'w'){ |f| f.puts example_yaml }
      example.run
      FileUtils.rm_r File.dirname(example_config)
    end

    context 'on success' do
      let(:example_yaml){ "---\ndefault:\n  foo: bar\n" }

      it 'returns a hash of attributes parsed' do
        expect(subject.read_from_disk).to eq(default: { foo: 'bar' })
      end
    end

    context 'on failure' do
      let(:example_yaml){ 'not real yaml' }

      it 'returns nil on any error' do
        expect(subject.read_from_disk).to be_nil
      end
    end
  end

  context '#write_to_disk' do
    let(:example_config){ File.expand_path('../tmp/thunder.yaml', __FILE__) }

    subject{ described_class.new(location: example_config) }

    after{ FileUtils.rm_r File.dirname(example_config) }

    it 'writes the internal attributes to a yaml file' do
      subject.populate!(default: {})
      subject.write_to_disk
      config = YAML.load File.read(example_config)
      expect(config).to eq('default' => {
                             'aws_access_key_id'     => nil,
                             'aws_secret_access_key' => nil,
                             'connection_options'    => nil,
                             'openstack_api_key'     => nil,
                             'openstack_auth_url'    => nil,
                             'openstack_tenant'      => nil,
                             'openstack_username'    => nil,
                             'region'                => nil })
    end
  end
end
