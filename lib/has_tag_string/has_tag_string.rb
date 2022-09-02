# lib/has_tag_string.rb:
# Lets a model have tags, represented as space separate strings in a public
# interface, but stored in the database as keys. Each tag can have a value
# followed by a colon - e.g. url:http://www.flourish.org
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: hello@mysociety.org; WWW: http://www.mysociety.org/

module HasTagString
  # Represents one tag of one model.
  # The migration to make this is currently only in WDTK code.
  class HasTagStringTag < ActiveRecord::Base
    # TODO: strip_attributes

    belongs_to :model, polymorphic: true

    validates_presence_of :name

    def self.from_string(tag)
      name, value = split_tag_into_name_value(tag)
      new(name: name, value: value)
    end

    # Return instance of the model that this tag tags
    def tagged_model
      model_type.constantize.find(model_id)
    end

    # For display purposes, returns the name and value as a:b, or
    # if there is no value just the name a
    def name_and_value
      ret = name
      ret += ':' + value unless value.nil?
      ret
    end

    # Parses a text version of one single tag, such as 'a:b' and returns
    # the name and value, with nil for value if there isn't one.
    def self.split_tag_into_name_value(tag)
      sections = tag.split(/:/)
      name = sections[0]
      if sections[1]
        value = sections[1, sections.size].join(':')
      else
        value = nil
      end
      [name, value]
    end
  end

  # Methods which are added to the model instances being tagged
  module InstanceMethods
    # Given an input string of tags, sets all tags to that string.
    # TODO: This immediately saves the new tags.
    def tag_string=(tag_string)
      tag_string = '' if tag_string.nil?

      tag_string = tag_string.strip
      # split tags apart
      tags = tag_string.split(/\s+/).uniq

      ActiveRecord::Base.transaction do
        self.tags.each(&:destroy)
        self.tags = []
        tags.each do |tag|
          # see if is a machine tags (i.e. a tag which has a value)
          name, value = HasTagStringTag.split_tag_into_name_value(tag)

          tag = HasTagStringTag.new(
            model_type: self.class.base_class.to_s,
            model_id: id,
            name: name, value: value
          )
          self.tags << tag
        end
      end
    end

    # Returns the tags the model has, as a space separated string
    def tag_string
      tags.map(&:name_and_value).join(' ')
    end

    # Returns the tags the model has, as an array of pairs of key/value
    # (this can't be a dictionary as you can have multiple instances of a
    # key with different values)
    def tag_array
      tags.map { |t| [t.name, t.value] }
    end

    # Returns a list of all the strings someone might want to search for.
    # So that is the key by itself, or the key and value.
    # e.g. if a request was tagged openlylocal_id:12345, they might
    # want to search for 'openlylocal_id' or for 'openlylocal_id:12345' to find
    # it.
    def tag_array_for_search
      ret = {}
      tags.each do |tag|
        ret[tag.name] = 1
        ret[tag.name_and_value] = 1
      end

      ret.keys.sort
    end

    # Test to see if class is tagged with the given tag
    def has_tag?(tag_as_string) # rubocop:disable Naming::PredicateName
      tags.each do |tag|
        return true if tag.name == tag_as_string
      end
      false
    end

    alias tagged? has_tag?

    class TagNotFound < StandardError
    end

    # If the tag is a machine tag, returns array of its values
    def get_tag_values(tag_as_string)
      found = false
      results = []
      tags.each do |tag|
        if tag.name == tag_as_string
          found = true
          results << tag.value unless tag.value.nil?
        end
      end
      raise TagNotFound unless found
      results
    end

    # Adds a new tag to the model, if it isn't already there
    def add_tag_if_not_already_present(tag_as_string)
      return tag_string if has_tag?(tag_as_string)
      self.tag_string = tag_string + ' ' + tag_as_string
    end

    # Removes tag to the model
    def remove_tag(tag_as_string)
      return tag_string unless has_tag?(tag_as_string)
      self.tag_string = tag_string.sub(/\b#{tag_as_string}\b/, '').strip
    end
  end

  # Methods which are added to the model class being tagged
  module ClassMethods
    # Find all public bodies with a particular tag
    def find_by_tag(tag_as_string)
      join_sql = <<-EOF.strip_heredoc.squish
      LEFT JOIN has_tag_string_tags
      ON has_tag_string_tags.model_type = '#{ self }'
      AND has_tag_string_tags.model_id = #{ table_name }.id
      EOF

      search =
        joins(join_sql).
        where(has_tag_string_tags: { name: tag_as_string, model_type: to_s }).
        references(:has_tag_string_tags)

      ordered =
        if respond_to?(:translated_locales)
          search.
            includes(:translations).
            references(:translations).
            merge(translation_class.order(:name))
        else
          search.order(:name)
        end

      ordered.distinct
    end
  end

  ######################################################################
  # Main entry point, add has_tag_string to your model.
  module HasMethods
    def has_tag_string # rubocop:disable Naming/PredicateName
      klass = to_s
      has_many :tags, -> { where(model_type: klass) },
               foreign_key: "model_id",
               class_name: 'HasTagString::HasTagStringTag'

      include InstanceMethods
      self.class.send :include, ClassMethods
    end
  end
end

ActiveRecord::Base.extend HasTagString::HasMethods
