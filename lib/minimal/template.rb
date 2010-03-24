class Minimal::Template
  autoload :FormBuilderProxy, 'minimal/template/form_builder_proxy'
  autoload :Handler,          'minimal/template/handler'

  AUTO_BUFFER = %r(render|tag|error_message_|select|debug|_to|_for)
  NO_AUTO_BUFFER = %r(form_tag|form_for)

  TAG_NAMES = %w(a body div em fieldset h1 h2 h3 h4 head html img input label li
    link ol option p pre script select span strong table thead tbody tfoot td th tr ul)

  module Base
    attr_reader :view, :buffers, :locals

    def initialize(view = nil)
      @view, @buffers, @locals = view, [], {}
    end

    def _render(locals = nil)
      @locals = locals || {}
      content
      view.output_buffer
    end

    TAG_NAMES.each do |name|
      module_eval(<<-"END")
        def #{name}(*args, &block)
          content_tag(:#{name}, *args, &block)
        end
      END

      module_eval(<<-"END")
        def #{name}_for(*args, &block)
          content_tag_for(:#{name}, *args, &block)
        end
      END

      # does not work in jruby 1.4.0 -> throws syntax error
      # define_method(name) { |*args, &block| content_tag(name, *args, &block) }
      # define_method("#{name}_for") { |*args, &block| content_tag_for(name, *args, &block) }
    end

    def <<(output)
      view.output_buffer << output
    end

    protected

      def method_missing(method, *args, &block)
        locals.key?(method) ? locals[method] :
          view.instance_variable_defined?("@#{method}") ? view.instance_variable_get("@#{method}") :
          view.respond_to?(method) ? call_view(method, *args, &block) : super
      end

      def call_view(method, *args, &block)
        block = lambda { |*a| self << view.with_output_buffer { yield(*a) } } if block
        view.send(method, *args, &block).tap { |result| self << result if auto_buffer?(method) }
      end

      def auto_buffer?(method)
        AUTO_BUFFER =~ method.to_s && NO_AUTO_BUFFER !~ method.to_s
      end
  end
  include Base
end
