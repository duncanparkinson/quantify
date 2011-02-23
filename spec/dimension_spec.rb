require 'quantify'
include Quantify

describe Dimensions do

  it "should hold array of recignised base quantities" do
    Dimensions::BASE_QUANTITIES. should == [
      :mass, :length, :time, :electric_current, :temperature,
      :luminous_intensity, :amount_of_substance, :information,
      :currency, :item ]
  end

  it "should return an array class variable" do
    Dimensions.dimensions.class.should == Array
  end

  it "class variable should contain dimension objects" do
    Dimensions.dimensions[0].class.should == Dimensions
    Dimensions.dimensions[1].class.should == Dimensions
  end

  it "should list all physical quantities as strings" do
    list = Dimensions.physical_quantities
    list.should include "acceleration"
    list.should include "force"
    list.should_not include :force
    list.should_not include "effort"
  end

  it "should return correct dimension object with symbol :length" do
    dimensions = Dimensions.for(:length)
    dimensions.class.should == Dimensions
    dimensions.length.should == 1
    dimensions.mass.should == nil
  end

  it "should return correct dimension object with symbol :energy" do
    dimensions = Dimensions.for(:energy)
    dimensions.class.should == Dimensions
    dimensions.length.should == 2
    dimensions.mass.should == 1
    dimensions.time.should == -2
    dimensions.luminous_intensity.should == nil
  end

  it "should return correct dimension object with string 'energy'" do
    dimensions = Dimensions.for('energy')
    dimensions.class.should == Dimensions
    dimensions.length.should == 2
    dimensions.mass.should == 1
    dimensions.time.should == -2
    dimensions.luminous_intensity.should == nil
  end

  it "should return correct dimension object with string 'length'" do
    dimensions = Dimensions.for('length')
    dimensions.class.should == Dimensions
    dimensions.length.should == 1
    dimensions.mass.should == nil
  end

  it "should raise error with invalid integer argument" do
    lambda{dimensions = Dimensions.for(1)}.should raise_error
  end

  it "should raise error with unknown dimension" do
    lambda{dimensions = Dimensions.for(:effort)}.should raise_error
  end

  it "should initialize a new object in @@dimensions class variable" do
    Dimensions.load :physical_quantity => :some_dimensions, :length => 12
    dimensions = Dimensions.for :some_dimensions
    dimensions.class.should == Dimensions
    dimensions.length.should == 12
  end

  it "should refuse to load new object in class array if no physical quantity" do
    lambda{Dimensions.load :mass => 1}.should raise_error
  end

  it "should refuse to load new object in class array if no physical quantity" do
    lambda{Dimensions.load :physical_quantity => nil, :mass => 1}.should raise_error
  end

  it "should create a new object with valid arguments" do
    dimensions = Dimensions.new :mass => 1, :length => -2
    dimensions.class.should == Dimensions
    dimensions.mass.should == 1
    dimensions.length.should == -2
    dimensions.time.should == nil
  end

  it "should raise error with invalid arguments" do
    lambda{dimension = Dimensions.new :acceleration => 1}.should raise_error
  end

  it "should identify the physical quantity and set ivar if known" do
    dimensions = Dimensions.new :mass => 1
    dimensions.describe.should == :mass
    dimensions.physical_quantity.should == :mass
  end

  it "should identify the physical quantity if known" do
    dimensions = Dimensions.new :mass => 1, :length => 2, :time => -2
    dimensions.describe.should == :energy
    dimensions.is_known?.should == true
  end

  it "should return nil if physical quantity not known" do
    dimensions = Dimensions.new :mass => 81, :length => 2, :time => -2
    dimensions.describe.should == nil
    dimensions.is_known?.should == false
  end

  it "should return the correct dimensions representation on multiplying" do
    dimensions_1 = Dimensions.for :length
    dimensions_2 = Dimensions.for :length
    dimensions_3 = dimensions_1 * dimensions_2
    dimensions_3.class.should == Dimensions
    dimensions_3.length.should == 2
    dimensions_3.physical_quantity.should == :area
  end

  it "should return the correct dimensions representation on dividing" do
    dimensions_1 = Dimensions.for :area
    dimensions_2 = Dimensions.for :length
    dimensions_3 = dimensions_1 / dimensions_2
    dimensions_3.class.should == Dimensions
    dimensions_3.length.should == 1
    dimensions_3.physical_quantity.should == :length
  end

  it "should return the correct dimensions representation on raising to power" do
    dimensions_1 = Dimensions.for :length
    dimensions_2 = dimensions_1 ** 2
    dimensions_2.class.should == Dimensions
    dimensions_2.length.should == 2
    dimensions_2.physical_quantity.should == :area
  end

  it "should return the correct dimensions representation on reciprocalize" do
    dimensions_1 = Dimensions.for :time
    dimensions_2 = dimensions_1.reciprocalize
    dimensions_2.class.should == Dimensions
    dimensions_2.time.should == -1
    dimensions_2.physical_quantity.should == :frequency
  end

  it "should retrieve the correct dimension with dynamic method" do
    Dimensions.acceleration.physical_quantity.should == :acceleration
  end

  it "should recognise length as a base quantity" do
    dimension = Dimensions.length
    dimension.is_base?.should == true
  end

  it "should recognise mass as a base quantity" do
    dimension = Dimensions.mass
    dimension.is_base?.should == true
  end

  it "should not recognise force as a base quantity" do
    dimension = Dimensions.force
    dimension.is_base?.should == false
  end

  it "should recognise plane angle as dimensionless" do
    dimension = Dimensions.plane_angle
    dimension.is_dimensionless?.should == true
  end

  it "should not recognise power as dimensionless" do
    dimension = Dimensions.power
    dimension.is_dimensionless?.should == false
  end

  it "should make an instance dimensionless" do
    dimension = Dimensions.power
    dimension.is_dimensionless?.should == false
    dimension
  end
end
