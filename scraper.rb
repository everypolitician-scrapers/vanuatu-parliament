#!/bin/env ruby
# encoding: utf-8

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(term, url)
  noko = noko_for(url)
  noko.css('.uk-table').xpath('.//tr[td]').each do |tr|
    tds = tr.css('td')
    name = tds[0].text.sub(/Hon.?\s*/, '').tidy
    next if tds.count < 2 || name.empty? || name.match(/Deces?ased/) || name == 'Vacant'

    data = {
      name: name,
      # role: tds[1].text.tidy,
      party: tds[2].text.tidy,
      constituency: tds[3].text.tidy,
      term: term,
      source: url.to_s
    }

    unless (mplink = tds[0].css('a/@href')).empty?
      data.merge!(scrape_person(URI.join(url, mplink.text)))
    end

    puts data.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']
    ScraperWiki.save_sqlite(%i[name party term], data)
  end
end

def scrape_person(url)
  noko = noko_for(url)
  data = {
    image: noko.css('a.thumbnail img/@src').text,
    source: url.to_s,
    id: url.to_s.split('/').last.split('-').first
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  data
end

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
scrape_list(11, 'https://parliament.gov.vu/index.php/memebers/members-of-11th-legislatture')
