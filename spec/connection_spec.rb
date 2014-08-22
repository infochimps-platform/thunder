require 'spec_helper'

describe Thunder::Connection do
  let(:example_config){ File.expand_path('../spec/tmp/thunder.yaml', __FILE__) }
  let(:example_options){ { config_file: example_config, config_section: 'extra' } }

  before(:all) do
    thunder_conf = File.expand_path('../spec/tmp/thunder.yaml', __FILE__)
    FileUtils.mkdir_p File.dirname(thunder_conf)
    File.open(thunder_conf, 'w'){ |f| f.puts "---\ndefault:\n  foo: bar\nextra:\n  baz: qix\n" }
  end

  after(:all){ FileUtils.rm_r File.dirname(example_config) }

  subject do
    connection_module = described_class
    overrides = example_options
    implementation = Class.new do
      include connection_module
      define_method(:options){ overrides }
    end
    implementation.new
  end

  context '#configuration' do
    it 'is memoized' do
      expect(subject.configuration).to be(subject.configuration)
    end

    it 'is populated correctly' do
      expect(subject.configuration[:baz]).to eq('qix')
    end
  end

  context '#implementation_selector' do
    context '--aws --no-openstack, flavor: aws' do
      let(:example_options){ { config_file: example_config, aws: true } }

      it 'selects :aws' do
        subject.configuration.stub(:[]).and_return(:aws)
        expect(subject.implementation_selector).to eq(:aws)
      end
    end

    context '--aws --openstack, flavor: aws' do
      let(:example_options){ { config_file: example_config, aws: true, openstack: true } }

      it 'selects :aws' do
        subject.configuration.stub(:[]).and_return(:aws)
        expect(subject.implementation_selector).to eq(:aws)
      end
    end

    context '--no-aws --openstack, flavor: aws' do
      let(:example_options){ { config_file: example_config, openstack: true } }

      it 'selects :openstack' do
        subject.configuration.stub(:[]).and_return(:aws)
        expect(subject.implementation_selector).to eq(:openstack)
      end
    end

    context '--no-aws --no-openstack, flavor: aws' do
      let(:example_options){ { config_file: example_config } }

      it 'selects :aws' do
        subject.configuration.stub(:[]).and_return(:aws)
        expect(subject.implementation_selector).to eq(:aws)
      end
    end

    context '--no-aws --no-openstack, flavor: openstack' do
      let(:example_options){ { config_file: example_config } }

      it 'selects :openstack' do
        subject.configuration.stub(:[]).and_return(:openstack)
        expect(subject.implementation_selector).to eq(:openstack)
      end
    end

    context '--no-aws --no-openstack, flavor: unspecified' do
      let(:example_options){ { config_file: example_config } }

      it 'selects :aws' do
        subject.configuration.stub(:[]).and_return(nil)
        expect(subject.implementation_selector).to eq(:aws)
      end
    end
  end

  context '#con' do
    it 'is memoized' do
      expect(subject.con).to be(subject.con)
    end

    context 'flavor :aws' do
      it 'selects the aws implementation' do
        expect(subject).to receive(:implementation_selector).and_return(:aws)
        expect(subject.con).to be_a(Thunder::CloudImplementation::AWS)
      end
    end

    context 'flavor :openstack' do
      it 'selects the aws implementation' do
        expect(subject).to receive(:implementation_selector).and_return(:openstack)
        expect(subject.con).to be_a(Thunder::CloudImplementation::Openstack)
      end
    end
  end
end
