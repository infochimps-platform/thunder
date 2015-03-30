require 'spec_helper'

describe Thunder::CloudImplementation::Openstack do
  it_behaves_like 'a cloud implementation'

  let(:options){ Hash.new }
  let(:test_json){ fixtures('test.json') }
  let(:test_ruby){ fixtures('test.rb') }

  subject{ described_class.new options }

  context '#template_parsers', '.json' do
    it 'parses json' do
      parser = subject.template_parsers(false)['.json']
      expect(parser.call test_json).to eq('foo' => 'bar')
    end
  end

  context '#template_parsers', '.rb' do
    it 'evaluates ruby' do
      parser = subject.template_parsers(false)['.rb']
      expect(parser.call test_ruby).to eq('AWSTemplateFormatVersion' => '2010-09-09',
                                          'Description' => 'Sample heat template')
    end
  end

  context '#template_parsers', '' do
    it 'throws an error if not using remote templates' do
      parser = subject.template_parsers(false)['']
      expect{ parser.call 'bad_file' }.to raise_error(Exception, /manually resupplied/)
    end
  end
end
