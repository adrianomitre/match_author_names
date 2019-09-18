#!/usr/bin/env ruby

require 'damerau-levenshtein'
require 'set'

module RobustAuthorNamesMatcher
  module_function

  def match_author_names(list_of_names)
    return Set.new if list_of_names.empty?
    result = []
    result << Set[list_of_names[0]]
    list_of_names[1..-1].each do |name|
      j = nil
      catch(:done) do
        result.each_with_index do |name_set, i|
          name_set.each do |name_set_name|
            if same_author?(name, name_set_name)
              j = i
              throw(:done)
            end
          end
        end
      end
      if j
        result[j] << name
      else
        result << Set[name]
      end
    end
    result.to_set
  end

  def string_distance(a, b)
    DamerauLevenshtein.string_distance(a, b, 1, 1_000)
  end

  def array_distance(a, b)
    DamerauLevenshtein.array_distance(a, b, 1, 1_000)
  end

  def relative_dist(a, b, callable)
    mean_sz = [a, b].sum(&:size) / 2.0
    callable.call(a, b) / mean_sz.to_f
  end

  CASE_SENSITIVE = false
  SAME_TOKEN_THRESHOLD = 1.0/3

  def same_token?(a, b,
      threshold: SAME_TOKEN_THRESHOLD,
      case_sensitive: CASE_SENSITIVE
    )
    a, b = [a, b].sort_by(&:size)
    a, b = [a, b].map(&:downcase) unless case_sensitive
    if a.size == 1
      a[0] == b[0]
    else
      relative_dist(a, b, method(:string_distance)) <= threshold
    end
  end

  SAME_AUTHOR_THRESHOLD = 0.2

  def same_author?(a, b, threshold: SAME_AUTHOR_THRESHOLD)
    authors_distance(a, b) <= threshold
  end

  def authors_distance(a, b)
    a, b = [a, b].sort_by(&:size)
    aw, bw = [a, b].map { |x| split_in_names_and_initials(x) }
    abw = aw + bw
    token_indices = abw.map { |w1| abw.index { |w2| same_token?(w1, w2) } }
    a, b = [token_indices[0, aw.size], token_indices[aw.size..-1]]
    if a.to_set.subset?(b.to_set)
      SAME_AUTHOR_THRESHOLD * 0.5
    else
      relative_dist(a, b, method(:min_rotated_array_distance))
    end
  end

  def split_in_names_and_initials(s)
    s.split(/(?:[.,]\s*)|\s+/)
  end

  def rotations(v)
    v.size.times.map { |i| v.rotate(i) }
  end

  def min_rotated_array_distance(u, v)
    rotations(u).min { |ru| array_distance(ru, v) }
  end
end

if __FILE__ == $PROGRAM_NAME
  list_of_names = ARGF.readlines.reject { |l| l.strip.empty? }
  name_sets = RobustAuthorNamesMatcher.match_author_names(list_of_names)
  name_sets.each do |set|
    set.each do |name|
      puts name
    end
    puts '-' * 80
  end
end
