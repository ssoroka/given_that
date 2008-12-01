require File.dirname(__FILE__) + '/../../config/environment'
require 'spec'

module GivenThatSpecHelper
  def caller_helper
    caller
  end

  def given_that(*args, &block)
    givens = args.dclone

    invoked_as = caller_helper.inject('given_that') { |called_as,trace|
      break($1.gsub(/_/, ' ')) if trace =~ /\d+:in `(given_.*?)'$/
      called_as
    }

    g = GivenThat.new(givens)

    g.read.each do |conditional_group|
      describe "#{invoked_as} " + conditional_group.to_sentence(:connector => g.pop_connector || 'and').gsub(/_/,' ') do
        before(:each) do
           conditional_group.each do |condition|
             send(condition)
           end
        end
        describe(&block)
      end
    end
  end
  alias :given_a        :given_that
  alias :given_an       :given_that
  alias :given_the      :given_that
  alias :given_this     :given_that
  alias :and_given_that :given_that
  alias :and_given_a    :and_given_that
  alias :and_given_an   :and_given_that
  alias :and_given_the  :and_given_that
  alias :and_given_this :and_given_that
end



class GivenThatNode
  attr_accessor :value, :parent, :children

  def initialize(val)
    @children = []
    @value = val.to_sym
  end

  def add_child(node_or_solution)
    node_or_solution.parent = self if node_or_solution.kind_of?(GivenThatNode)
    @children << node_or_solution
    node_or_solution
  end
end

class GivenThatRootNode < GivenThatNode
  def initialize
    super(:nil)
  end
end

class GivenThatOperatorNode < GivenThatNode
end

# token nodes are now solutions.  solutions are either nodes, or nodes that have been ANDed or ORed together
# solution & solution == solution
# solution | solution | solution == solution
# this can be used to reduce operator nodes and their children down into single solution objects.
# The final solution object reduced from all the other solution objects and operators is the solution for the parse tree.
class GivenThatSolution < Array
  attr_accessor :connectors

  def initialize(*args)
    args.each{|arg|
      self << arg
    }
  end

  def &(target)
    out = []
    self.each {|solution|
      target.each{|target_solution|
        out << (solution + target_solution)
      }
    }
    GivenThatSolution.new(*out)
  end

  def |(target)
    GivenThatSolution.new(*(self + target))
  end
end

class GivenThat
  MULTIPLICATIVE_OPERATORS = [:or]
  ADDITIVE_OPERATORS = [:and, :with]

  def initialize(parts)
    @tree = GivenThatRootNode.new
    build_tree(@tree, tokenize(parts))
  end

  def read
    read_tree
  end

  def push_connector(connector)
    @connectors ||= []
    @connectors <<  case connector
                    when GivenThatNode
                      connector.value.to_s
                    when String
                      connector
                    else
                      connector.to_s
                    end
  end

  def pop_connector
    @connectors.shift
  rescue
    nil
  end

  private
  def multiplicative_regexp
    @additive_regexp ||= /^(#{MULTIPLICATIVE_OPERATORS.map{ |o| o.to_s }.join("|")})_/
  end

  def additive_regexp
    @additive_regexp ||= /^(#{ADDITIVE_OPERATORS.map{ |o| o.to_s }.join("|")})_/
  end

  def combined_regexp
    @combined_regexp ||= /^(#{MULTIPLICATIVE_OPERATORS.map{ |o| o.to_s }.join("|")}|#{ADDITIVE_OPERATORS.map{ |o| o.to_s }.join("|")})_/
  end

  def tokenize(parts)
    operator = false

    # find operator for this layer, strip it from any symbols
    parts.each do |p|
      if p.to_s =~ multiplicative_regexp
        operator = $1.to_sym
      elsif MULTIPLICATIVE_OPERATORS.any? { |o| p.respond_to?(:to_sym) && o.to_sym == p.to_sym }
        operator = p.to_sym
      elsif p.to_s =~ additive_regexp
        operator = $1.to_sym
      elsif ADDITIVE_OPERATORS.any? { |o| p.respond_to?(:to_sym) && o.to_sym == p.to_sym }
        operator = p.to_sym
      end
      break if operator
    end

    operator ||= ADDITIVE_OPERATORS.first # default to :and

    parts = parts.delete_if {|p| MULTIPLICATIVE_OPERATORS.include?(p) || ADDITIVE_OPERATORS.include?(p) }

    # tokenize array elements and strip remaining or/and
    parts.map!{|p| p.is_a?(Array) ? tokenize(p) : p.to_s.gsub(combined_regexp, '').to_sym }

    # prepend operator to the array
    parts.unshift(operator)
    parts
  end

  def build_tree(node, parts)
    curr = node.add_child(GivenThatOperatorNode.new(parts.shift))
    parts.each{|part|
      if part.is_a?(Array)
        build_tree(curr, part)
      else
        curr.add_child(GivenThatSolution.new([part]))
      end
    }
  end

  def read_tree
    read_operator_node(@tree.children.first)
  end

  # read_operator_node should only be called on operator_nodes.
  # it will read all children and AND or OR them together, calling read_operator_node as
  # necessary to resolve child operator nodes.
  def read_operator_node(node)
    first_node = node.children.first
    solution = first_node.is_a?(GivenThatOperatorNode) ? read_operator_node(first_node) : first_node

    push_connector(node)
    #group =
    node.children[1..-1].inject(solution) do |sum, i|
      i = read_operator_node(i) if i.is_a?(GivenThatOperatorNode)
      if MULTIPLICATIVE_OPERATORS.include?(node.value)
        sum = sum | i
      else # Assume it's in ADDITIVE_OPERATORS
        sum = sum & i
      end
    end
  end

end

module Spec
  module Mocks
    class BaseExpectation
      def times_called
        @actual_received_count
      end
    end
  end
end
