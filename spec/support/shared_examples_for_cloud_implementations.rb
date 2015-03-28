shared_examples 'a cloud implementation' do
  context '#get_template_text', 'with key' do
    let(:template){ { '_thunder_url' => 'foo' } }

    it 'returns the template string' do
      expect(subject.get_template_text(template)).to eq('foo')
    end
  end

  context '#get_template_text', 'without key' do
    let(:template){ { 'foo' => 'bar' } }

    it 'returns the template string' do
      expect(subject.get_template_text(template)).to eq('{"foo":"bar"}')
    end
  end

  context '#hashload' do
    let(:parsers){ subject.template_parsers false }

    it 'raises an error on unsupported file extensions' do
      expect{ subject.hashload('bad.txt', parsers) }.to raise_error(Exception, /bad\.txt/)
    end

    it 'loads json files' do
      expect(subject.hashload(test_json, parsers)).to eq('foo' => 'bar')
    end

    it 'loads files from the internet' do
      # This needs to be stubbed in a better way
      url = 'https://gist.githubusercontent.com/kornypoet/2c825f87b96feba4278b/raw/9f5dd4e3d9fb23a9ab912462d8556122de8f6c96/gistfile1.json'
      expect(subject.hashload(url, parsers)).to eq('foo' => 'bar', '_thunder_url' => url)
    end
  end
end
