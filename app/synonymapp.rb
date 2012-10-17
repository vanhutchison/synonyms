# app.rb

require 'sinatra'
require 'haml'
require 'Mysql2'

use Rack::MethodOverride

# configure do
#   set :method_override, true
# end


set :haml, :format => :html5, :layout => :app_layout
client = Mysql2::Client.new(:host => "localhost", :username => "root")
PAGE_SIZE = 30

#  HELPERS
# 
helpers do
  def highlight(text, phrases)
    
    options = {:highlighter => '<strong class="highlight">\1</strong>' }

    if text.nil? || phrases.nil?
      text
    else
      match = Array(phrases).map { |p| Regexp.escape(p) }.join('|')
      text.gsub(/(#{match})(?!(?:[^<]*?)(?:["'])[^<>]*>)/i, options[:highlighter])
    end
  end

  def  pluralize(count, singular, plural = nil)
    "#{count || 0} " + ((count == 1 || count =~ /^1(\.0+)?$/) ? singular : (plural || "#{singular}s"))
  end
end


# 
# ROUTES
# 
get '/' do
  'Hello world!'
end

get '/words' do
  redirect '/words/A'
end
get '/words/:letter' do
  # page = params[:page] && params[:page].to_i > 0 ? params[:page].to_i : 1
  # offset = PAGE_SIZE * ( page - 1)
  letter = params[:letter]
  if !('A'..'Z').to_a.include?(letter) && letter!= '0'
    letter = 'A'
  end
  # words = client.query("SELECT * FROM synonyms.words ORDER BY word ASC  LIMIT #{PAGE_SIZE} OFFSET #{offset}")
  if letter == '0'
    words = client.query("SELECT * FROM synonyms.words WHERE word NOT REGEXP '^[[:alpha:]]' ORDER BY word ASC")
  else
    words = client.query("SELECT * FROM synonyms.words WHERE word LIKE '#{letter}%' ORDER BY word ASC")
  end
  haml :words, :locals => {words: words, path: '/words'}
end

get '/words/nosynonyms' do
  redirect '/words/nosynonyms/A'
end


get '/words/nosynonyms/:letter' do

  # page = params[:page] && params[:page].to_i > 0 ? params[:page].to_i : 1
  # offset = PAGE_SIZE * ( page - 1)
  letter = params[:letter]
  if !('A'..'Z').to_a.include?(letter) && letter!= '0'
    letter = 'A'
  end

  if letter == '0'
    words = client.query("SELECT w.* FROM synonyms.words w LEFT JOIN synonyms.word_synonyms  ws ON( ws.word_id = w.id) " +
                        " WHERE w.word  NOT REGEXP '^[[:alpha:]]'  AND ws.id IS NULL ORDER BY word ASC ")
  else
    words = client.query("SELECT w.* FROM synonyms.words w LEFT JOIN synonyms.word_synonyms  ws ON( ws.word_id = w.id) " +
                        " WHERE w.word LIKE '#{letter}%' AND ws.id IS NULL ORDER BY word ASC ")
  end

  
  haml :words, :locals => {words: words, path: '/words/nosynonyms'}
end

get '/words/synonyms' do
  redirect '/words/synonyms/A'
end
get '/words/synonyms/:letter' do
  
  # page = params[:page] && params[:page].to_i > 0 ? params[:page].to_i : 1
  # offset = PAGE_SIZE * ( page - 1)
  letter = params[:letter]
  if !('A'..'Z').to_a.include?(letter) && letter!= '0'
    letter = 'A'
  end

  if letter == '0'
    words = client.query("SELECT w.* FROM synonyms.words w LEFT JOIN synonyms.word_synonyms  ws ON( ws.word_id = w.id) " +
                        " WHERE w.word   NOT REGEXP '^[[:alpha:]]'  AND ws.id IS NOT NULL ORDER BY word ASC ")
  else
    words = client.query("SELECT w.* FROM synonyms.words w LEFT JOIN synonyms.word_synonyms  ws ON( ws.word_id = w.id) " +
                        " WHERE w.word LIKE '#{letter}%' AND ws.id IS NOT NULL ORDER BY word ASC ")
  end

  
  haml :words, :locals => {words: words, path: '/words/synonyms'}
end

get '/word/:id' do
  word = client.query("SELECT * FROM synonyms.words WHERE id = #{params[:id].to_i}").first
  questions = client.query("SELECT q.* FROM synonyms.word_questions wq JOIN synonyms.questions q ON(wq.question_id=q.id ) WHERE word_id = #{params[:id].to_i}")
  synonyms = client.query("SELECT * FROM synonyms.word_synonyms  WHERE word_id = #{params[:id].to_i} ").first

  haml :word, :locals => {word: word, questions: questions, synonyms: synonyms}
end

get '/word/:id/delete' do
  client.query("DELETE * FROM synonyms.words WHERE id = #{params[:id].to_i}")
  client.query("DELETE * FROM synonyms.word_synonyms  WHERE word_id = #{params[:id].to_i} ")
  

  redirect "/words/A"
end

post '/word/:id/synonyms' do
  if params[:synonyms]
    synonyms = client.query("SELECT * FROM synonyms.word_synonyms  WHERE word_id = #{params[:id].to_i} ").first

    new_synonyms = params[:synonyms].split(',').map{|w| w.strip}.reject{|w| w.split.length > 1 }.join(',')
    if synonyms != new_synonyms
      new_synonyms = client.escape(new_synonyms)
      if synonyms
        word = client.query("UPDATE synonyms.word_synonyms SET  synonyms='#{new_synonyms}' WHERE word_id = #{params[:id].to_i} ")
      else
        word = client.query("INSERT INTO synonyms.word_synonyms (word_id,synonyms,created_at,modified_at) VALUES ( #{params[:id].to_i}, '#{new_synonyms}' ,NOW(),NOW() ) ")
      end
    end
  end

  redirect "/word/#{params[:id]}"
end

get '/synonyms/download' do
  attachment "synonyms.txt"
  words = client.query("SELECT w.word,ws.* FROM synonyms.words w JOIN synonyms.word_synonyms ws ON(ws.word_id=w.id) ORDER BY word ASC")
  list = ''
  words.each do |row|
    list << "\##{row['word']}"
    list << row['synonyms']
  end
  list
end


get '/stop-words' do
  words = client.query("SELECT * FROM synonyms.stop_words ORDER BY word ASC")
  haml :stop_words, :locals => {words: words}
end

post '/stop-words' do
  word = client.escape(params[:word])
  if word
    client.query("INSERT IGNORE INTO synonyms.stop_words (word,created_at,modified_at) VALUES ( '#{word}',NOW(),NOW() ) ")
  end
  redirect '/stop-words'
end

get '/stop-words/:id/delete' do
  client.query("DELETE FROM synonyms.stop_words WHERE id=#{params[:id].to_i}")
  redirect '/stop-words'
end


