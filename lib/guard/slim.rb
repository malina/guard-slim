require 'guard'
require 'guard/plugin'
require 'guard/watcher'
require 'slim'

module Guard
  class Slim < Plugin
    autoload :Notifier, 'guard/slim/notifier'

    def initialize(opts = {})
      opts = {
        notifications:        true,
        default_ext:          'html',
        auto_append_file_ext: false
      }.merge(opts)

      super(opts)

      if options[:input]
        watchers << ::Guard::Watcher.new(%r{^#{options[:input]}/([\w\-_]+(\.html)?\.slim)$})
      end
    end

    def start
      run_all if options[:run_at_start]
    end

    def stop
      true
    end

    def reload
      run_all
    end

    def run_all
      run_on_changes(Watcher.match_files(self, Dir.glob(File.join('**', '*.*'))))
    end

    def run_on_changes(paths)
      paths.each do |file|
        output_paths = _output_paths(file)
        compiled_slim = compile_slim(file)

        output_paths.each do |output_file|
          FileUtils.mkdir_p File.dirname(output_file)
          File.open(output_file, 'w') { |f| f.write(compiled_slim) }
        end

        message = "Successfully compiled slim to html!\n"
        message += "# #{file} -> #{output_paths.join(', ')}".gsub("#{::Bundler.root.to_s}/", '')
        ::Guard::UI.info message
        Notifier.notify(true, message) if options[:notifications]
      end
    end

    private

    def compile_slim(file)
      begin
        content = File.new(file).path
        engine  = ::Slim::Template.new(content, (options[:slim_options] || {}))
        engine.render
      rescue StandardError => error
        message = "slim compilation of #{file} failed!\nError: #{error.message}"
        ::Guard::UI.error message
        Notifier.notify(false, message) if options[:notifications]
        throw :task_has_failed
      end
    end

    # Get the file path to output the html based on the file being
    # built. The output path is relative to where guard is being run.
    #
    # @param file [String, Array<String>] path to file being built
    # @return [Array<String>] path(s) to file where output should be written
    #
    def _output_paths(file)
      input_file_dir = File.dirname(file)
      file_name = _output_filename(file)
      file_name = "#{file_name}.html" if _append_html_ext_to_output_path?(file_name)
      input_file_dir = input_file_dir.gsub(Regexp.new("#{options[:input]}(\/){0,1}"), '') if options[:input]

      if options[:output]
        Array(options[:output]).map do |output_dir|
          File.join(output_dir, input_file_dir, file_name)
        end
      else
        if input_file_dir == ''
          [file_name]
        else
          [File.join(input_file_dir, file_name)]
        end
      end
    end

    # Generate a file name based on the provided file path.
    # Provide a logical extension.
    #
    # Examples:
    #   "path/foo.slim"     -> "foo.html"
    #   "path/foo"          -> "foo.html"
    #   "path/foo.bar"      -> "foo.bar.html"
    #   "path/foo.bar.slim" -> "foo.bar"
    #
    # @param file String path to file
    # @return String file name including extension
    #
    def _output_filename(file)
      sub_strings           = File.basename(file).split('.')
      base_name, extensions = sub_strings.first, sub_strings[1..-1]

      if extensions.last == 'slim'
        extensions.pop
        if extensions.empty?
          [base_name, options[:default_ext]].join('.')
        else
          [base_name, extensions].flatten.join('.')
        end
      else
        [base_name, extensions, options[:default_ext]].flatten.join('.')
      end
    end

    def _append_html_ext_to_output_path?(filename)
      return unless options[:auto_append_file_ext]

      filename.match("\.html?").nil?
    end
  end
end
