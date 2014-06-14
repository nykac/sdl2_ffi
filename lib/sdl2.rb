require 'sdl2/sdl_module'
require 'active_support/inflector'
require 'enumerable_constants'
require 'sdl2/stdinc'
require 'sdl2/debug'
# The SDL2 Map of API Prototypes
module SDL2
  extend FFI::Library
  extend Library
  ffi_lib SDL_MODULE

  ##
  # A struct helper provides member_reader/member_writer helpers for quickly accessing those damn members.
  # This is extended into sdl2_ffi's usage of Structs, ManagedStructs, and Unions. Do I know exatcly what I'm
  # doing, no... but teach me what I'm doing wrong.
  module StructHelper
    # Define a set of member readers
    # Ex1: `member_readers [:one, :two, :three]`
    # Ex2: `member_readers *members`
    def member_readers(*members_to_define)
      members_to_define.each do |member|
        define_method member do
          self[member]
        end
      end

    end

    # Define a set of member writers
    # Ex1: `member_writers [:one, :two, :three]`
    # Ex2: `member_writers *members`
    def member_writers(*members_to_define)
      members_to_define.each do |member|
        define_method "#{member}=".to_sym do |value|
          self[member]= value
        end
      end
    end

  end

  ##
  # BadQuanta: I Augmented for compares with anything that can be an array
  class FFI::Struct::InlineArray
    def ==(other)
      self.to_a == other.to_a
    end
  end

  ##
  # BadQuanta: sdl2_ffi messes with the FFI::Struct class for some useful additions.
  class Struct < FFI::Struct
    extend StructHelper
    ##
    # Allows creation and use within block, automatically freeing pointer after block.
    def initialize(*args, &block)
      super(*args)
      if block_given?
        throw 'Release must be defined to use block' unless self.class.respond_to?(:release)
        yield self
        self.class.release(self.pointer)
      end
    end

    ##
    # Placeholder for Structs that need to initialize values.
    def self.create(values = {})
      created = self.new
      created.update_members(values)
      created
    end

    ##
    # A default release scheme is defined, but should be redefined where appropriate.
    def self.release(pointer)
      puts "#{self.to_s}::release() called from: \n #{caller.join("\n")}"
      pointer.free
    end

    ##
    # A default free operation, but should be redefined where appropriate.
    # TODO: Is this wrong to do in conjuction with release?
    def free()
      self.pointer.free
    end

    # A human-readable representation of the struct and it's values.
    #def inspect
    #  return 'nil' if self.null?
    #
    #  #binding.pry
    #  #return self.to_s
    #
    #      report = "struct #{self.class.to_s}{"
    #      report += self.class.members.collect do |field|
    #        "#{field}->#{self[field].inspect}"
    #      end.join(' ')
    #      report += "}"
    #    end

    ##
    # Compare two structures by class and values.
    # This will return true when compared to a "partial hash" and
    # all the key/value pairs the hash defines equal the
    # corrisponding members in the structure.
    # Otherwise all values must match between structures.
    # TODO: CLEAN UP THIS COMPARISON CODE!!!
    def ==(other)
      Debug.log(self){
        "COMPARING #{self} to #{other}"
      }

      result = catch(:result) do
        unless self.class == other.class or other.kind_of? Hash
          Debug.log(self){"Class Mismatch"}
          throw :result, false
        end

        if (other.kind_of? Hash) and (other.keys - members).any?
          Debug.log(self){"Extra Keys: #{other.keys-members}"}
          thorw :result, false
        end

        if (other.respond_to?:null?) and (self.null? or other.null?)
          unless self.null? and other.null?
            Debug.log(self){"AHHHAOne is null and the other is not"}
            throw :result, false
          end
        else
          fields = other.kind_of?(Hash) ? members & other.keys : members
          fields.each do |field|
            Debug.log(self){"#{field}:#{self[field].class} = "}

            unless self[field] == other[field]

              Debug.log(self){"NO MATCH: #{self[field].to_s} #{other[field].to_s}"}
              throw :result, false
            end
            Debug.log(self){"MATCH"}
          end
        end

        # Everything passed
        throw :result, true

      end
      Debug.log(self){
        "RESULT = #{result}"
      }
      return result
    end

    ##
    # Default cast handler.
    #
    #
    # BadQuanta says:
    #   Casting means to take something and try to make it into a Structure
    #   - Other instances of the same class (simply returns that instance)
    #   - Any hash, this structure will be "created" with the has specifying members.
    #   - A nil object, which will return the same nil object assuming that is o.k.
    def self.cast(something)

      if something.kind_of? self

        return something

      elsif something.kind_of? Hash

        return self.create(something)

      elsif something.nil?

        return something #TODO: Assume NUL is ok?

      else

        raise "#{self} can't cast #{something.insepct}"

      end
    end

    ##
    # Set members to values contained within hash.
    def update_members(values)
      if values.kind_of? Array
        raise "#{self} has less fields then #{values.inspect}" if values.count > members.count
        members.first(values.count).each_with_index do |field, idx|
          self[field] = values[idx]
        end

      elsif values.kind_of? Hash
        common = (self.members & values.keys)
        common.each do |field|
          self[field] = values[field]
        end
      elsif values.kind_of? self.class
        members.each do |member|
          self[member] = values[member]
        end
      else
        raise "#{self}#update_members unable to update from #{values.inspect}"
      end
    end

    ##
    # Human readable translation of a structure
    def to_s
      null = self.to_ptr.null?
      values = members.map do |member|
        "#{member}=#{null ? 'null' : self[member]}"
      end unless null
      "<#{self.class.to_s} #{null ? 'NULL' : values.join(' ')}>"
    end
  end

  ##
  # FFI::ManagedStruct possibly with useful additions.
  class ManagedStruct < FFI::ManagedStruct
    extend StructHelper
    # Allows create and use the struct within a block.
    def initialize(*args, &block)
      super(*args)
      if block_given?
        yield self
      end
    end

  end

  ##
  # BadQuanta says: "Even FFI::Unions can be helped."
  class Union < FFI::Union
    extend StructHelper
  end

  ##
  # BadQuanta says: "Typed pointes let you get to the value."
  class TypedPointer < Struct
    
      
    def self.type(kind)
      layout :value, kind
    end

    def value
      self[:value]
    end

    alias_method :deref, :value

    # Simple Type Structures to interface 'typed-pointers'
    # TODO: Research if this is the best way to handle 'typed-pointers'
    class Float < TypedPointer
      type :float
    end

    # Int-typed pointer
    class Int < TypedPointer
      type :int
    end

    #
    class UInt16 < TypedPointer
      type :uint16
    end

    class UInt32 < TypedPointer
      type :uint32
    end

    class UInt8 < TypedPointer
      type :uint8
    end

  end
  
  module BLENDMODE
    include EnumerableConstants
    NONE = 0x00000000
    BLEND = 0x00000001
    ADD = 0x00000002
    MOD = 0x00000004
  end
  # TODO: Review if this is the best place to put it.
  # BlendMode is defined in a header file that is always included, so I'm
  # defineing again here.
  enum :blend_mode, BLENDMODE.flatten_consts

  class BlendModeStruct < SDL2::TypedPointer
    layout :value, :blend_mode
  end

  

  # Simple typedef to represent array sizes.
  typedef :int, :count

end

require 'sdl2/init'

#TODO: require 'sdl2/assert'
#TODO: require 'sdl2/atomic'
require 'sdl2/audio'
require 'sdl2/clipboard'
require 'sdl2/cpuinfo'

#TODO: require 'sdl2/endian'
require 'sdl2/error'
require 'sdl2/events'
require 'sdl2/joystick'
require 'sdl2/gamecontroller'
require 'sdl2/haptic'
require 'sdl2/hints'
require 'sdl2/log'

#TODO: require 'sdl2/messagebox'
#TODO: require 'sdl2/mutex'
require 'sdl2/power'
require 'sdl2/render'
require 'sdl2/rwops'

#TODO: require 'sdl2/system'
#TODO: require 'sdl2/thread'
require 'sdl2/timer'
require 'sdl2/version'
require 'sdl2/video'