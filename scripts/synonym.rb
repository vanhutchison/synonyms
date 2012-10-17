#!/Users/vanessa/.rvm/rubies/ruby-1.9.3-p194/bin/ruby

require 'mysql2'
# require 'sqlite'


def is_a_number?(s)
  s.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true 
end

DEBUG = true



new_words = []
word_ids = {}
client = Mysql2::Client.new(:host => "localhost", :username => "root")

# get the stop words, we don't car about those
STOP_WORDS = []
results = client.query( "SELECT word FROM synonyms.stop_words " )
results.each do |row|
  STOP_WORDS.push row['word']
end


# load questions 
questions_list = File.open('../data/questions-list.txt')
question_count = 0


questions_list.each do |line|
    
  # save question in database if it's not there
  question_id = nil
  question_escape = client.escape(line)
  results = client.query( "SELECT id FROM synonyms.questions WHERE question='#{question_escape}' " )
  results.each do |row|
    question_id = row['id']
  end
  if question_id.nil?
    insert = client.query( "INSERT INTO synonyms.questions (question,created_at,modified_at) VALUES ( '#{question_escape}',NOW(),NOW() ) " )
    question_id = client.last_id

    puts "insert question" if DEBUG
  end


  # split the words
  body = line.downcase.split.map {|str| str.gsub(/^[^a-z0-9]+|[\.\*\#\^\%\$\/]|[^a-z0-9]+$/i,'') }.reject {|str| STOP_WORDS.include?(str) || is_a_number?(str)  || str.length < 3|| str.length > 20}
  
  if DEBUG
    puts "question:#{line}"
    puts "words: #{body.join(',')}" 
    puts "\n"
  end

  new_words.push body

  body.each do |word|

    # add each word to db if not already
    word_id = nil
    word_escaped = client.escape(word)

    results = client.query( "SELECT id FROM synonyms.words WHERE word='#{word_escaped}' " )
    results.each do |row|
      word_id = row['id']
    end

    if word_id.nil?
      insert = client.query( "INSERT INTO synonyms.words (word,created_at,modified_at) VALUES ( '#{word_escaped}',NOW(),NOW() ) " )
      word_id = client.last_id
      puts "insert word" if DEBUG
    end

    # save the words db id for later
    word_ids[word] = word_id

    # associate question to words
    client.query( "INSERT IGNORE INTO synonyms.word_questions (word_id,question_id,created_at,modified_at) VALUES ( #{word_id},#{question_id},NOW(),NOW() ) " )

  end

  question_count+=1
  
end

# get unique list of all the words 
new_words.flatten!.uniq!


puts "questions: #{question_count}, words: #{new_words.count} \n\n" if DEBUG



words_found = 0
words_notfound = 0


# go through each word and find the synonyms
new_words.each do |word|
    
  puts word if DEBUG

  # grep through the thesaurus
  IO.popen( "grep \"^#{word}\", ../data/mthesaur.txt ") do |f| 
    synonyms = f.gets

    if synonyms.nil?
      puts "#{word} not found "+"\n"*2 if DEBUG
      words_notfound+=1
    else
      # if found synonyms then add to db
      words_found +=1

      syn_words = synonyms.split(',').reject {|str|  str.split(' ').length > 1 }

      # merge any existing
      existing_synonyms = nil
      row_exists = false
      results = client.query( "SELECT synonyms FROM synonyms.word_synonyms WHERE word_id=#{word_ids[word]} " )
      results.each do |row|
        row_exists = true
        if row['existing_synonyms']
          existing_synonyms = row['existing_synonyms'].split(',')
          syn_words += existing_synonyms
          syn_words.uniq!
        end
      end

      # save to db
      syn_words_escape = client.escape( syn_words.join(',') )

      if row_exists
        client.query( "REPLACE INTO synonyms.word_synonyms (word_id,synonyms,modified_at) VALUES ( #{word_ids[word]},'#{syn_words_escape}',NOW() ) " )
      else
        client.query( "INSERT INTO synonyms.word_synonyms (word_id,synonyms,created_at,modified_at) VALUES ( #{word_ids[word]},'#{syn_words_escape}',NOW(),NOW() ) " )
      end

    end
  end
end

puts "#{words_found} #{words_notfound}" if DEBUG

# puts words_notfound
# puts word_synonyms