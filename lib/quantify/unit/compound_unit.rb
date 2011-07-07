
module Quantify
  module Unit
    class Compound < Base

      # Compound units are units made up of two or more units and powers thereof.
      #
      # The relationships between these units represent multiplication or division.
      # E.g. a 'kilowatt hour' is the unit derived from multiplying a kilowatt and
      # an hour. The 'kilogram per cubic metre' similarly represents the kilogram
      # divided by the cubic metre (which itself represents metre x metre x metre).
      #
      # There are many SI units and NonSI units which are technically compound
      # units - being derived from several base units. For example, the watt
      # represents the joule (itself compound) divided by the second. In this
      # case though, the use of a special name for the unit - the 'watt' rather
      # than the 'kilogram square metre per cubic second' - allows it to be
      # treated as a standard SI unit.
      #
      # The Compound class provides support for arbitrarily defined compound units
      # which don't have well-established names.



      # Consilidates base quantities by finding multiple instances of the same unit
      # type and reducing them into a single unit represenation, by altering the
      # repsective index. It has the effect of raising units to powers and cancelling
      # those which appear in the numerator AND denominator
      #
      # This is a class method which takes an arbitrary array of base units as an
      # argument. This means that consolidation can be performed on either all
      # base units or just a subset - the numerator or denominator units.
      #
      def self.consolidate_base_units(base_units)
        raise Exceptions::InvalidArgumentError, "Must provide an array of base units" unless base_units.is_a? Array

        new_base_units = []

        while base_units.size > 0 do
          new_base = base_units.shift
          next if new_base.unit.is_dimensionless?

          new_base.index = base_units.select do |other_base|
            new_base.unit.is_equivalent_to? other_base.unit
          end.inject(new_base.index) do |index,other_base|
            base_units.delete other_base
            index += other_base.index
          end

          new_base_units << new_base unless new_base.is_dimensionless?
        end
        return new_base_units
      end

      # Make compound unit use consistent units for representing each physical
      # quantity. For example, lb/kg => kg/kg.
      #
      # This is a class method which takes an arbitrary array of base units as an
      # argument. This means that consolidation can be performed on either all
      # base units or just a subset - e.g. the numerator or denominator units.
      #
      # The units to use for particular physical dimension can be specified
      # following the inital argument. If no unit is specified for a physical
      # quantity which is represented in the array of base units, then the first
      # unit found for that physical quantity is used as the canonical one.
      #
      def self.rationalize_base_units(base_units=[],*required_units)
        base_units.each do |base|
          new_unit = required_units.map { |unit| Unit.for(unit) }.find { |unit| unit.measures == base.measures } ||
            base_units.find { |unit| unit.measures == base.measures }.unit
          base.unit = new_unit
        end
      end

      attr_reader :base_units, :acts_as_equivalent_unit

      # Initialize a compound unit by providing an array containing a represenation
      # of each base unit.
      #
      # Array may contain elements specified as follows:
      #
      #  1. a instance of CompoundBaseUnit
      #
      #  2. an instance of Unit::Base (in which case its index is assumed as 1
      #
      #  3. a sub-array of size 2 containing an instance of Unit::Base and an
      #     explicit index
      #
      def initialize(*units)
        @base_units = []
        units.each do |unit|
          if unit.is_a? CompoundBaseUnit
            @base_units << unit
          elsif unit.is_a? Unit::Base
            @base_units << CompoundBaseUnit.new(unit)
          elsif unit.is_a?(Array) && unit.first.is_a?(Unit::Base) &&
              !unit.first.is_a?(Compound) && unit.size == 2
            @base_units << CompoundBaseUnit.new(unit.first,unit.last)
          else
            raise Exceptions::InvalidArgumentError, "#{unit} does not represent a valid base unit"
          end
        end
        @acts_as_alternative_unit = true
        @acts_as_equivalent_unit = false
        consolidate_numerator_and_denominator_units!
      end


      # Returns an array containing only the base units which have positive indices
      def numerator_units
        @base_units.select { |base| base.is_numerator? }
      end

      # Returns an array containing only the base units which have negative indices
      def denominator_units
        @base_units.select { |base| base.is_denominator? }
      end

      # Convenient accessor method for pluralized names
      def pluralized_name
        derive_name :plural
      end

      # Determine is a unit object represents an SI named unit.
      #
      def is_si_unit?
        @base_units.all? { |base| base.is_si_unit? }
      end

      def is_non_si_unit?
        @base_units.any? { |base| base.is_non_si_unit? }
      end

      def is_base_quantity_si_unit?
        @base_units.all? { |base| base.is_base_quantity_si_unit? }
      end

      # Consolidate base units. A 'full' consolidation is performed, i.e.
      # consolidation across numerator and denominator. This is equivalent to the
      # automatic partial consolidation AND a cancelling of units (i.e.
      # #cancel_base_units!)
      #
      def consolidate_base_units!
        @base_units = Compound.consolidate_base_units(@base_units)
        initialize_attributes
        return self
      end

      # Cancel base units across numerator and denominator. If similar units occur
      # in both the numerator and denominator, they can be cancelled, i.e. their
      # powers reduced correspondingly until one is removed.
      #
      # This method is useful when wanting to remove specific units that can be
      # cancelled from the compound unit configuration while retaining the
      # remaining units in the current format.
      #
      # If no other potentially cancelable units need to be retained, the method
      # #consolidate_base_units! can be called with the :full argument instead
      #
      # This method takes an arbitrary number of arguments which represent the units
      # which are required to be cancelled (string, symbol or object)
      #
      def cancel_base_units!(*units)
        units.each do |unit|
          raise Exceptions::InvalidArgumentError, "Cannot cancel by a compound unit" if unit.is_a? Unit::Compound
          unit = Unit.for unit unless unit.is_a? Unit::Base

          numerator_unit = numerator_units.find { |base| unit.is_equivalent_to? base.unit }
          denominator_unit = denominator_units.find { |base| unit.is_equivalent_to? base.unit }

          if numerator_unit && denominator_unit
            cancel_value = [numerator_unit.index,denominator_unit.index].min.abs
            numerator_unit.index -= cancel_value
            denominator_unit.index += cancel_value
          end
        end
        consolidate_numerator_and_denominator_units!
      end

      # Make the base units of self use consistent units for each physical quantity
      # represented. For example, lb/kg => kg/kg.
      #
      # By default, units are rationalized within the the numerator and denominator
      # respectively. That is, different units representing the same physical
      # quantity may appear across the numerator and denominator, but not within
      # each. To fully rationalize the base units of self, pass in the symbol
      # :full as a first argument. Otherwise :partial is passed as the default.
      #
      # The units to use for particular physical dimension can be specified
      # following the inital argument. If no unit is specified for a physical
      # quantity which is represented in the array of base units, then the first
      # unit found for that physical quantity is used as the canonical one.
      #
      def rationalize_base_units!(scope=:partial,*units)
        if scope == :full
          Compound.rationalize_base_units(@base_units,*units)
        else
          Compound.rationalize_base_units(numerator_units,*units)
          Compound.rationalize_base_units(denominator_units,*units)
        end
        consolidate_numerator_and_denominator_units!
      end

      # Return a known unit which is equivalent to self in terms of its physical
      # quantity (dimensions), factor and scaling attributes (i.e. representing the
      # precise same physical unit but perhaps with different identifiers), e.g.
      #
      #   ((Unit.kg*(Unit.m**"))/(Unit.s**2)).equivalent_known_unit.name
      #
      #                                #=> "joule"
      #
      def equivalent_known_unit
        Unit.units.find do |unit|
          self.is_equivalent_to?(unit) && !unit.is_compound_unit?
        end
      end

      # Returns an equivalent known unit (via #equivalent_known_unit) if it exists.
      # Otherwise, returns false.
      #
      def or_equivalent
        equivalent_unit = equivalent_known_unit
        if equivalent_unit && equivalent_unit.acts_as_equivalent_unit
          return equivalent_unit
        else
          return self
        end
      end

      protected

      def initialize_attributes
        self.dimensions = derive_dimensions
        self.name = derive_name
        self.symbol = derive_symbol
        self.factor = derive_factor
        self.label = derive_label
      end

      # Partially consolidate base units, i.e. numerator and denomiator are
      # consolidated separately. This means that two instances of the same unit
      # should not occur in the numerator OR denominator (rather they are combined
      # and the index changed accordingly), but similar units are not cancelled
      # across the numerator and denominators.
      #
      def consolidate_numerator_and_denominator_units!
        new_base_units = []
        new_base_units += Compound.consolidate_base_units(numerator_units)
        new_base_units += Compound.consolidate_base_units(denominator_units)
        @base_units = new_base_units
        initialize_attributes
        return self
      end

      # Derive a representation of the physical dimensions of the compound unit
      # by multilying together the dimensions of each of the base units.
      #
      def derive_dimensions
        @base_units.inject(Dimensions.dimensionless) do |dimension,base|
          dimension * base.dimensions
        end
      end

      # Derive a name for the unit based on the names of the base units
      #
      # Both singluar and plural names can be derived. In the case of pluralized
      # names, the last unit in the numerator is pluralized. Singular names are
      # assumed by default, in which case no argument is required.
      #
      # Format for names includes the phrase 'per' to differentiate denominator
      # units and words, rather than numbers, for representing powers, e.g.
      #
      #   square metres per second
      #
      def derive_name(inflection=:singular)
        unit_name = ""
        unless numerator_units.empty?
          units = numerator_units
          last_unit = units.pop if inflection == :plural
          units.inject(unit_name) do |name,base|
            name << base.name + " "
          end
          unit_name << last_unit.pluralized_name + " " if last_unit
        end
        unless denominator_units.empty?
          unit_name << "per "
          denominator_units.inject(unit_name) do |name,base|
            name << base.name + " "
          end
        end
        return unit_name.strip
      end

      # Derive a symbol for the unit based on the symbols of the base units
      # 
      # Get the units in order first so that the denominator values (those
      # with negative powers) follow the numerators
      #
      # Symbol format use unit symbols, with numerator symbols followed by
      # denominator symbols and powers expressed using the "^" notation with 'true'
      # values (i.e. preservation of minus signs).
      #
      def derive_symbol
        @base_units.sort do |base,next_unit|
          next_unit.index <=> base.index
        end.inject('') do |symbol,base|
          symbol << base.symbol + " "
        end.strip
      end

      # Derive a label for the comound unit. This follows the format used in the
      # JScience library in using a middot notation ("·") to spearate units and
      # slash notation "/" to separate numerator and denominator. Since the
      # denominator is differentiated, denominator unit powers are rendered in
      # absolute terms (i.e. minus sign omitted) except when no numerator values
      # are present.
      #
      def derive_label
        unit_label = ""
        unless numerator_units.empty?
          numerator_units.inject(unit_label) do |label,base|
            label << "·" unless unit_label.empty?
            label << base.label
          end
        end

        unless denominator_units.empty?
          format = ( unit_label.empty? ? :label : :reciprocalized_label )
          unit_label << "/" unless unit_label.empty?
          denominator_units.inject(unit_label) do |label,base|
            label << "·" unless unit_label.empty? || unit_label =~ /\/\z/
            label << base.send(format)
          end
        end
        return unit_label
      end

      # Derive the multiplicative factor for the unit based on those of the base
      # units
      #
      def derive_factor
        @base_units.inject(1) do |factor,base|
          factor * base.factor
        end
      end

    end
  end
end