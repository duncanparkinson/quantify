# encoding: UTF-8

module Quantify
  module Unit

    extend ExtendedMethods

    # The Unit module contains functionality for defining and handling
    # representations of physical units.
    #
    # All units are defined using the Unit::SI and Unit::NonSI classes, both of
    # which inherit from Unit::Base.
    #
    # New units can be defined to represent whatever is required. However a
    # system of known units is stored in the Unit module instance variable
    # @units, accessible using Unit.units. These known units can be configured
    # to represent which ever units are required. The Unit module will handle
    # any combinations of units and prefixes according to the known units and
    # prefixes specified in config.rb. New units can be defined (with or without
    # prefixes) at any time and either used in place or loaded into the known
    # system.

    class << self
      attr_reader :units
    end

    # Instance variable containing system of known units
    @units = []

    def self.configure(&block)
      self.class_eval(&block) if block
    end

    # Set the default string which is used to delimit numerator and denominator
    # strings in compound unit symbol representations. Defaults to "/".
    #
    def self.symbol_denominator_delimiter=(string)
      @symbol_denominator_delimiter = string
      refresh_all_unit_attributes!
    end

    def self.symbol_denominator_delimiter
      @symbol_denominator_delimiter ||= "/"
    end

    # Set the default string which is used to delimit unit symbol strings in
    # compound unit symbol representations. Defaults to " ".
    #
    def self.symbol_unit_delimiter=(string)
      @symbol_unit_delimiter = string
      refresh_all_unit_attributes!
    end

    def self.symbol_unit_delimiter
      @symbol_unit_delimiter ||= " "
    end

    # Specify whether parentheses should be used to group multiple units in
    # compound unit symbol representations. Set either <tt>true</tt> (e.g.
    # "kg/(t km)") or <tt>false</tt> (e.g. "kg/t km"). Defaults to <tt>false</tt>
    #
    def self.use_symbol_parentheses=(true_or_false)
      @use_symbol_parentheses = true_or_false
      refresh_all_unit_attributes!
    end

    # Shorthand bang! method for configuring parentheses in compound unit symbol
    # representations
    #
    def self.use_symbol_parentheses!
      @use_symbol_parentheses = true
    end

    # Returns <tt>true</tt> if parentheses are configured for use within compound
    # unit symbol representations. Otherwise returns <tt>false</tt>.
    #
    def self.use_symbol_parentheses?
      @use_symbol_parentheses.nil? ? false : @use_symbol_parentheses
    end

    # Shorthand bang! method for configuring denominator structures in compound
    # unit symbol representations (e.g. "kg/t km")
    #
    def self.use_symbol_denominator_syntax!
      self.use_symbol_denominator_syntax = true
    end

    # Shorthand bang! method for configuring index-only structures in compound
    # unit symbol representations (e.g. "kg t^-1 km^-1")
    #
    def self.use_symbol_indices_only!
      self.use_symbol_denominator_syntax = false
    end

    # Specify whether denominator structures should be used in compound unit
    # symbol representations. Set either <tt>true</tt> (e.g. "kg/t km") or
    # <tt>false</tt> (e.g. "kg t^-1 km^-1"). Defaults to <tt>true</tt>
    #
    def self.use_symbol_denominator_syntax=(true_or_false)
      @use_symbol_denominator_syntax = true_or_false
      refresh_all_unit_attributes!
    end

    # Returns <tt>true</tt> if denominator structures are configured for use
    # within compound unit symbol representations. Otherwise returns
    # <tt>false</tt>.
    #
    def self.use_symbol_denominator_syntax?
      @use_symbol_denominator_syntax.nil? ? true : @use_symbol_denominator_syntax
    end

    # Check whether superscript characters are turned on.
    def self.use_superscript_characters?
      @use_superscript_characters.nil? ? true : @use_superscript_characters
    end

    # Shorthand method for ::use_superscript_characters=true
    def self.use_superscript_characters!
      self.use_superscript_characters = true
    end

    # Declare whether superscript characters should be used for unit names, symbols
    # and labels - i.e. "²" and "³" rather than "^2" and "^3". Set to either true or
    # false. If not set, superscript characters are used by default.
    #
    def self.use_superscript_characters=(true_or_false)
      raise Exceptions::InvalidArgumentError,
        "Argument must be true or false" unless true_or_false == true || true_or_false == false
      @use_superscript_characters = true_or_false
      refresh_all_unit_attributes!
    end

    # Switch all unit identifiers (name, symbol, label) to use the currently
    # configured system for superscripts.
    #
    def self.refresh_all_unit_attributes!
      Unit.units.replace(
        Unit.units.map { |unit| unit.refresh_attributes; unit }
      )
    end

    # Load a new unit into they system of known units
    def self.load(unit)
      @units << unit if unit.is_a? Unit::Base
    end

    # Remove a unit from the system of known units
    def self.unload(*unloaded_units)
      [unloaded_units].flatten.each do |unloaded_unit|
        @units.delete(Unit.for(unloaded_unit))
      end
    end

    # Returns an instance of the class Quantity which represents the ratio of two
    # units. For example, the ratio of miles to kilometers is 1.609355, or there
    # are 1.609355 km in 1 mile.
    #
    #   ratio = Unit.ratio :km, :mi         #=> <Quantify::Quantity:0xj9ab878a7>
    #
    #   ratio.to_s :name                    #=> "1.609344 kilometres per mile"
    #
    # In other words the quantity represents the definition of one unit in terms
    # of the other.
    #
    def self.ratio(unit,other_unit)
      unit = Unit.for unit
      other_unit = Unit.for other_unit
      unless unit.is_alternative_for? other_unit
        raise Exceptions::InvalidUnitError, "Units do not represent the same physical quantity"
      end
      new_unit = (unit / other_unit)
      value = 1/new_unit.factor
      Quantity.new(value, new_unit)
    end

    def self.dimensionless
      Unit::Base.new(:dimensions => 'dimensionless') do |unit|
        unit.acts_as_alternative_unit = false
      end
    end

    # Retrieve an object representing the specified unit.
    #
    # Argument can be the unit name, symbol or JScience label and provided as
    # a string or a symbol, e.g.
    #
    #   Unit.for :metre
    #
    #   Unit.for 'kilogram'
    #
    # This can be shortened to, for example, Unit.metre by virtue of the
    # #method_missing method (see below)
    #
    # This method will recognise valid combinations of known units and prefixes,
    # irrespective of whether the prefixed unit has been initialized into the
    # system of known units in it's own right. For example,
    #
    #   Unit.centimetre ... or, alternatively ... Unit.cm
    #
    # will return a Unit::SI object with attributes representing a centimetre
    # based on the initialized Unit for :metre and Prefix :centi.
    #
    def self.for(name_symbol_label_or_object)
      return name_symbol_label_or_object.clone if name_symbol_label_or_object.is_a? Unit::Base
      return nil if name_symbol_label_or_object.nil? ||
        ( name_symbol_label_or_object.is_a?(String) && name_symbol_label_or_object.empty? )
      name_symbol_or_label = name_symbol_label_or_object
      unless name_symbol_or_label.is_a?(String) || name_symbol_or_label.is_a?(Symbol)
        raise Exceptions::InvalidArgumentError, "Argument must be a Symbol or String"
      end
      if unit = Unit.match(name_symbol_or_label)
        return unit
      elsif unit = Unit.parse(name_symbol_or_label)
        return unit
      elsif unit = Unit.parse(name_symbol_or_label, :iterative => true)
        return unit
      else
        return nil
      end
    rescue Exceptions::InvalidUnitError
      return nil
    end

    # Parse complex strings into unit.
    #
    def self.parse(string, options={})
      string = string.remove_underscores.without_superscript_characters
      units = options[:iterative] == true ? Unit.iterative_parse(string) : Unit.simple_parse(string)
      return nil if units.empty?
      return units.first.unit if units.size == 1 && units.first.index == 1
      return Unit::Compound.new(*units)
    end

    def self.match(name_symbol_or_label)
      return name_symbol_or_label.clone if name_symbol_or_label.is_a? Unit::Base
      Unit.match_known_unit_or_prefixed_variant(:label, name_symbol_or_label) or
      Unit.match_known_unit_or_prefixed_variant(:name, name_symbol_or_label) or
      Unit.match_known_unit_or_prefixed_variant(:symbol, name_symbol_or_label)
    end

    protected

    def self.match_known_unit_or_prefixed_variant(attribute, string_or_symbol)
      Unit.match_known_unit(attribute, string_or_symbol) or
      Unit.match_prefixed_variant(attribute, string_or_symbol)
    end

    def self.match_known_unit(attribute, string_or_symbol)
      string_or_symbol = Unit.format_unit_attribute(attribute, string_or_symbol)
      @units.find do |unit|
        unit_attribute = unit.send(attribute)
        if attribute == :name
          unit_attribute.downcase == string_or_symbol
        else
          unit_attribute == string_or_symbol
        end
      end.clone rescue nil
    end

    def self.match_prefixed_variant(attribute, string_or_symbol)
      string_or_symbol = Unit.format_unit_attribute(attribute, string_or_symbol)
      if string_or_symbol =~ /\A(#{units_for_regex(Unit::Prefix,:si_prefixes,attribute)})(#{units_for_regex(Unit,:si_non_prefixed_units,attribute)})\z/ ||
         string_or_symbol =~ /\A(#{units_for_regex(Unit::Prefix,:non_si_prefixes,attribute)})(#{units_for_regex(Unit,:non_si_non_prefixed_units,attribute)})\z/
        return Unit.for($2).with_prefix($1).clone
      end
      return nil
    end

    def self.simple_parse(string)
      if string.scan(/(\/|per)/).size > 1
        raise Exceptions::InvalidArgumentError, "Malformed unit: multiple uses of '/' or 'per'"
      end
      units = []
      numerator, per, denominator = string.split(/(\/|per)/)
      units += Unit.parse_numerator_units(numerator)
      units += Unit.parse_denominator_units(denominator) unless denominator.nil?
      return units
    end

    def self.iterative_parse(string)
      units=[]
      current_set = "numerator_units"
      while unit = Unit.unit_label_regex.match(string) || unit = Unit.unit_symbol_regex.match(string) ||
          unit = Unit.unit_name_regex.match(string) || unit = Unit.unit_denominator_regex.match(string) do
        if unit[0] =~ Unit.unit_denominator_regex
          current_set = "denominator_units"
        else
          units += Unit.send("parse_#{current_set}".to_sym, unit[0])
        end
        # Remove matched pattern from string for next iteration
        match_length = unit[0].size
        string = string[match_length, string.length-match_length].strip
      end
      return units
    end
    
    def self.parse_unit_and_index(string)
      string.scan(/([^0-9\^]+)\^?([\d\.-]*)?/i)
      index = ($2.nil? || $2.empty? ? 1 : $2.to_i)
      unit = Unit.match($1.to_s)
      if unit.is_a? Compound
        return unit.base_units.each {|base_unit| base_unit.index = base_unit.index * index}
      else
        return CompoundBaseUnit.new($1.to_s, index)
      end
    end

    def self.parse_numerator_units(string)
      # If no middot then names parsed by whitespace
      if string =~ /·/
        num_units = string.split("·")
      else
        num_units = Unit.escape_multi_word_units(string).split(" ")
      end
      num_units.map! do |substring|
        Unit.parse_unit_and_index(substring)
      end.flatten
    end

    def self.parse_denominator_units(string)
      Unit.parse_numerator_units(string).map do |unit|
        unit.index *= -1
        unit
      end
    end

    # standardize query strings or symbols into canonical form for unit names,
    # symbols and labels
    #
    def self.format_unit_attribute(attribute, string_or_symbol)
      string_or_symbol = case attribute
        when :symbol then string_or_symbol.remove_underscores
        when :name then string_or_symbol.remove_underscores.singularize.downcase
        else string_or_symbol.to_s
      end
      Unit.use_superscript_characters? ?
        string_or_symbol.with_superscript_characters : string_or_symbol.without_superscript_characters
    end
    
    # This returns the suite of units which represents THE SI units for each of
    # the base dimensions, i.e. metre, kilogram, second, etc. but not prefixed
    # versions of the same unit
    #
    def self.base_quantity_si_units
      @units.select {|unit| unit.is_base_quantity_si_unit? }
    end

    # This can be replicated by method missing approach, but explicit method provided
    # given importance in #match (and #for) methods regexen
    #
    def self.si_non_prefixed_units
      @units.select {|unit| unit.is_si_unit? && !unit.is_prefixed_unit? }
    end

    # This can be replicated by method missing approach, but explicit method provided
    # given importance in #match (and #for) methods regexen
    #
    def self.non_si_non_prefixed_units
      @units.select {|unit| unit.is_non_si_unit? && !unit.is_prefixed_unit? }
    end

    # Return a list of unit names which are multi-word
    def self.multi_word_unit_names
      @units.map {|unit| unit.name if unit.name.word_count > 1 }.compact
    end

    # Return a list of pluralised unit names which are multi-word
    def self.multi_word_unit_pluralized_names
      multi_word_unit_names.map {|name| name.pluralize }
    end

    # Return a list of unit symbols which are multi-word
    def self.multi_word_unit_symbols
      @units.map {|unit| unit.symbol if unit.symbol.word_count > 1 }.compact
    end

    # might want to try atomic groupings, but must get units in size order perhaps first
    def self.unit_label_regex
      /\A((#{Unit.units_for_regex(Unit::Prefix,:non_si_prefixes,:label)})?((#{Unit.units_for_regex(Unit,:non_si_non_prefixed_units,:label)})\b)|(#{Unit.units_for_regex(Unit::Prefix,:si_prefixes,:label)})?((#{Unit.units_for_regex(Unit,:si_non_prefixed_units,:label)})\b))(\^[\d\.-]*)?/
    end

    def self.unit_symbol_regex
      /\A((#{Unit.units_for_regex(Unit::Prefix,:si_prefixes,:symbol)})?((#{Unit.units_for_regex(Unit,:si_non_prefixed_units,:symbol)})\b)|(#{Unit.units_for_regex(Unit::Prefix,:non_si_prefixes,:symbol)})?((#{Unit.units_for_regex(Unit,:non_si_non_prefixed_units,:symbol)})\b))(\^[\d\.-]*)?/
    end

    def self.unit_name_regex
      # Specifically case insensitive
      /\A((#{Unit.units_for_regex(Unit::Prefix,:non_si_prefixes,:name)})?((#{Unit.units_for_regex(Unit,:non_si_non_prefixed_units,:pluralized_name)}|#{Unit.units_for_regex(Unit,:non_si_non_prefixed_units,:name)})\b)|(#{Unit.units_for_regex(Unit::Prefix,:si_prefixes,:name)})?((#{Unit.units_for_regex(Unit,:si_non_prefixed_units,:pluralized_name)}|#{Unit.units_for_regex(Unit,:si_non_prefixed_units,:name)})\b))(\^[\d\.-]*)?/i
    end

    def self.unit_denominator_regex
      /\A(\/|per)/i
    end

    # Underscore any parts of string which represent multi-word unit identifiers
    # so that units can be parsed on whitespace
    #
    def self.escape_multi_word_units(string)
      (multi_word_unit_symbols + multi_word_unit_pluralized_names + multi_word_unit_names).each do |id|
        string.gsub!(id, id.gsub(" ","_")) if /#{id}/.match(string)
      end
      string
    end

    # Returns a list of "|" separated unit identifiers for use as regex
    # alternatives. Lists are constructed by calling 
    def self.units_for_regex(klass,method,attribute)
      list = klass.send(method).map { |item| item.send(attribute).gsub("/","\\/").gsub("^","\\^")  }
      list.map! { |item| item.downcase } if attribute == :name
      list.sort {|x, y| y.size <=> x.size }.join("|")
    end

  end
end
