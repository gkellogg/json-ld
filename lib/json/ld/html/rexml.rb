require 'htmlentities'

module JSON::LD
  class API
    ##
    # REXML implementation of an XML parser.
    #
    # @see http://www.germane-software.com/software/rexml/
    module REXML
      ##
      # Returns the name of the underlying XML library.
      #
      # @return [Symbol]
      def self.library
        :rexml
      end

      # Proxy class to implement uniform element accessors
      class NodeProxy
        attr_reader :node
        attr_reader :parent

        def initialize(node, parent = nil)
          @node = node
          @parent = parent
        end

        ##
        # Return xml:base on element, if defined
        #
        # @return [String]
        def base
          @node.attribute("base", RDF::XML.to_s) || @node.attribute('xml:base')
        end

        def display_path
          @display_path ||= begin
            path = []
            path << parent.display_path if parent
            path << @node.name
            case @node
            when ::REXML::Element   then path.join("/")
            when ::REXML::Attribute then path.join("@")
            else path.join("?")
            end
          end
        end

        ##
        # Return true of all child elements are text
        #
        # @return [Array<:text, :element, :attribute>]
        def text_content?
          @node.children.all? {|c| c.is_a?(::REXML::Text)}
        end

        ##
        # Children of this node
        #
        # @return [NodeSetProxy]
        def children
          NodeSetProxy.new(@node.children, self)
        end

        # Ancestors of this element, in order
        def ancestors
          @ancestors ||= parent ? parent.ancestors + [parent] : []
        end

        ##
        # Inner text of an element
        #
        # @see http://apidock.com/ruby/REXML/Element/get_text#743-Get-all-inner-texts
        # @return [String]
        def inner_text
          coder = HTMLEntities.new
          ::REXML::XPath.match(@node,'.//text()').map { |e|
            coder.decode(e)
          }.join
        end

        ##
        # Inner text of an element
        #
        # @see http://apidock.com/ruby/REXML/Element/get_text#743-Get-all-inner-texts
        # @return [String]
        def inner_html
          @node.children.map(&:to_s).join
        end

        def attribute_nodes
          attrs = @node.attributes.dup.keep_if do |name, attr|
            !name.start_with?('xmlns')
          end
          @attribute_nodes ||= (attrs.empty? ? attrs : NodeSetProxy.new(attrs, self))
        end

        ##
        # Node type accessors
        #
        # @return [Boolean]
        def text?
          @node.is_a?(::REXML::Text)
        end

        def element?
          @node.is_a?(::REXML::Element)
        end

        def blank?
          @node.is_a?(::REXML::Text) && @node.empty?
        end

        def to_s; @node.to_s; end

        def xpath(*args)
          ::REXML::XPath.match(@node, *args).map do |n|
            NodeProxy.new(n, parent)
          end
        end

        def at_xpath(*args)
          xpath(*args).first
        end

        ##
        # Proxy for everything else to @node
        def method_missing(method, *args)
          @node.send(method, *args)
        end
      end

      ##
      # NodeSet proxy
      class NodeSetProxy
        attr_reader :node_set
        attr_reader :parent

        def initialize(node_set, parent)
          @node_set = node_set
          @parent = parent
        end

        ##
        # Return a proxy for each child
        #
        # @yield child
        # @yieldparam [NodeProxy]
        def each
          @node_set.each do |c|
            yield NodeProxy.new(c, parent)
          end
        end

        ##
        def to_html
          node_set.map(&:to_s).join("")
        end

        ##
        # Proxy for everything else to @node_set
        def method_missing(method, *args)
          @node_set.send(method, *args)
        end
      end

      ##
      # Initializes the underlying XML library.
      #
      # @param  [Hash{Symbol => Object}] options
      # @return [void]
      def initialize_html(input, options = {})
        require 'rexml/document' unless defined?(::REXML)
        @doc = case input
        when ::REXML::Document
          input
        else
          # Only parse as XML, no HTML mode
          ::REXML::Document.new(input.respond_to?(:read) ? input.read : input.to_s)
        end
      end

      # Accessor methods to mask native elements & attributes

      ##
      # Return proxy for document root
      def root
        @root ||= NodeProxy.new(@doc.root) if @doc && @doc.root
      end

      ##
      # Document errors
      def doc_errors
        []
      end

      ##
      # Find value of document base
      #
      # @param [String] base Existing base from URI or :base_uri
      # @return [String]
      def doc_base(base)
        # find if the document has a base element
        base_el = ::REXML::XPath.first(@doc, "/html/head/base") rescue nil
        base.join(base_el.attribute("href").to_s.split("#").first) if base_el
      end
    end
  end
end