require 'spec_helper'

describe Thunder::App do

  context 'running `thunder`' do
    it 'shows help output' do
      run_simple 'thunder'
      assert_exit_status 0
      expect(all_output).to match <<-HELP.gsub(/^ {8}/, '')
        Commands:
          thunder config .*
          thunder config_import .*
          thunder help .*
          thunder keypair .*
          thunder poll .*
          thunder remote_file .*
          thunder sherpa .*
          thunder stack .*
      HELP
    end
  end

  context 'running `thunder config`' do
    subject{ Thunder::App.new }

    it 'populates a thunder config file' do
      # subject.options = { config_file: File.expand_path('../tmp/thunder.yaml', __FILE__) }
      # subject.config
      # puts File.read(File.expand_path('../tmp/thunder.yaml', __FILE__))
    end
  end
end
