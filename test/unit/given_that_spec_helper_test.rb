# this should be converted to rspec.  it doesn't play nice.
require File.join(File.dirname(__FILE__), '..', '..', 'spec', 'additions', 'given_that_spec_helper')

require 'test/unit'

class GivenThatSolutionTest < Test::Unit::TestCase
  def test_oring_two_one_element_arrays
    assert_equal [[:a], [:b]], GivenThatSolution.new([:a]) | GivenThatSolution.new([:b])
  end

  def test_anding_two_one_element_arrays
    assert_equal [[:a, :b]], GivenThatSolution.new([:a]) & GivenThatSolution.new([:b])
  end

  def test_anding_two_two_element_arrays
    assert_equal [[:a, :b, :c, :d]], GivenThatSolution.new([:a, :b]) & GivenThatSolution.new([:c, :d])
  end

  def test_oring_two_two_element_arrays
    assert_equal [[:a, :b], [:c, :d]], GivenThatSolution.new([:a, :b]) | GivenThatSolution.new([:c, :d])
  end

  def test_anding_in_creation
    assert_equal [[:a, :b], [:c, :d]], GivenThatSolution.new([:a, :b], [:c, :d])
  end

  def test_anding_arrays_of_different_sizes
    assert_equal [[:a, :c], [:b, :c]], GivenThatSolution.new([:a], [:b]) & GivenThatSolution.new([:c])
  end

  def test_anding_anded_arrays
    assert_equal [[:a, :c], [:a, :d], [:b, :c], [:b, :d]], GivenThatSolution.new([:a], [:b]) & GivenThatSolution.new([:c], [:d])
  end

  def test_oring_anded_arrays
    assert_equal [[:a], [:b], [:c], [:d]], GivenThatSolution.new([:a], [:b]) | GivenThatSolution.new([:c], [:d])
  end
end

class GivenThatTest < Test::Unit::TestCase
  def setup
    @gt = GivenThat.new( [] )
  end

  def test_push_connector_appends
    @gt.push_connector( 'a' )
    @gt.push_connector( 'b' )
    @gt.push_connector( 'c' )
    assert_equal ['a', 'b', 'c'], @gt.instance_variable_get( '@connectors' )
  end

  def test_pop_connector_pulls_from_the_front
    @gt.push_connector( 'd' )
    @gt.push_connector( 'e' )
    @gt.push_connector( 'f' )
    assert_equal 'd', @gt.pop_connector
    assert_equal 'e', @gt.pop_connector
    assert_equal 'f', @gt.pop_connector
  end

  def test_pop_connector_returns_nil_if_empty
    assert_equal nil, @gt.pop_connector
  end

  def test_symbol_should_turn_into_string
    @gt.push_connector( :thursday )

    connector = @gt.pop_connector
    assert_equal 'thursday', connector
    assert_kind_of String, connector
  end

  def test_given_that_node_should_turn_into_string
    @gt.push_connector( GivenThatNode.new( :funktastic ) )

    connector = @gt.pop_connector
    assert_equal 'funktastic', connector
    assert_kind_of String, connector
  end
end

class GivenThatSpecHelperTest < Test::Unit::TestCase
  include GivenThatSpecHelper

  [ :given_a, :given_an, :given_the, :given_this ].each do |alias_name|
    define_method( "test_alias_#{alias_name.to_s}" ) do
      assert_equal given_that( :a, :b, :c ), send( alias_name, :a, :b, :c )
    end
  end

  [ :and_given_that, :and_given_a, :and_given_an, :and_given_the, :and_given_this ].each do |alias_name|
    define_method( "test_alias_#{alias_name.to_s}" ) do
      assert_equal given_that( :a, :b, :c ), send( alias_name, :a, :b, :c )
    end
  end

  def test_and_on_level_one
    #       root
    #        |
    #       and
    #     /  |  \
    # one  two   three

    assert_equal [[:one,:two,:three]], given_that(:one, :two, :and_three)
  end

  def test_with_on_level_one
    #       root
    #        |
    #       with
    #     /  |  \
    # one  two   three

    assert_equal [[:one,:two,:three]], given_that(:one, :two, :with_three)
  end

  def test_bad_operator_on_level_one
    #       root
    #        |
    #      monkey
    #     /  |  \
    # one  two   three

    assert_equal [[:one,:two,:monkey_three]], given_that(:one, :two, :monkey_three)
  end

  def test_and_on_level_one_plus_or_on_level_two
    #       root
    #        |
    #       and
    #     /  |  \
    # one  two   or
    #           /    \
    #         three  four

    assert_equal [[:one,:two,:three], [:one, :two, :four]], given_that(:one, :two, :and, [:three, :or, :four])
  end

  def test_or_on_level_one
    #       root
    #        |
    #       or
    #     /  |  \
    # one  two   three

    assert_equal [[:one],[:two],[:three]], given_that(:one, :two, :or_three)
  end

  def test_or_on_level_one_plus_and_on_level_two
    #       root
    #        |
    #       or
    #     /  |  \
    # one  two   and
    #           /    \
    #         three  four
  
    assert_equal [[:one],[:two],[:three,:four]], given_that(:one, :two, :or, [:three, :and, :four])
  end

  def test_and_on_level_one_plus_two_ors_on_level_two
    #              root
    #               |
    #              and
    #            /    \
    #          or      or
    #        / \      /  \
    #       a   b   two  three

    assert_equal [[:a,:two],[:a,:three],[:b,:two],[:b,:three]], given_that([:a, :or_b], :and, [:two, :or_three])
  end

  def test_and_on_level_one_plus_or_on_level_two_plus_and_on_level_three
    #       root
    #        |
    #       and # => => [[:one, :two], [:one, :three, :four]]
    #     /     \
    # one         or # => [[:two], [:three, :four]]
    # ^-- [[:one]] * [[:two], [:three, :four]]
    #           /    \
    #          two   and  # => [[:three, :four]]
    #               /   \
    #            three  four 

    assert_equal [[:one,:two],[:one,:three,:four]], given_that(:one, :and, [:two, :or, [:three, :and, :four]])
  end

  def test_methods_should_be_called_when_given_a_block
    given_that( :first_method, :and, :second_method ) do
      it 'should be awesome' do
        # At least one of them should always be true
        ( $first_method_was_called || $second_method_was_called ).should == true
        # Booo globals!
      end
    end
  end
end

def first_method
  $first_method_was_called = true
end

def second_method
  $second_method_was_called = true
end
