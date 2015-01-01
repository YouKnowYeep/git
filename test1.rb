require 'nokogiri'
require 'open-uri'
require 'rubygems'
require 'mysql'
require 'dbi'
require 'thread'


$unVisitUrl=Queue.new
$unVisitUrl.push("http://www.baidu.com/s?wd=ruby")
$hasVisitedUrl=Hash.new
$tempContent=[]
$id=1
$dbh=DBI.connect("DBI:Mysql:SpiderDb:localhost","root","lyp")
threads=[]
def search(url)
	page=Nokogiri::HTML(open(url))
	title=page.css('title').text #get  current page's title
	pageContent=page.css('div#content_left h3') #get current page's content
	relatedTitle=page.css('div#rs th') #get related search title
	relatedUrl=page.css('div#rs a') #get current page's related search url

	relatedTitle.each do |relatedTitle|
		str=relatedTitle.text.strip
		sth1=$dbh.prepare("insert into related (url,entryName) values (?,?)")
		sth1.execute(url,str)
	end
	relatedUrl.each do |relatedUrl|
		str='http://www.baidu.com'+relatedUrl['href']
		$unVisitUrl.push(str)
		sth2=$dbh.prepare("update related set entryUrl=? where id=?")
		sth2.execute(str,$id)
		$id+=1
	end
	pageContent.each do |pageContent|
		$tempContent<<pageContent.text.strip
	end
	temp=$tempContent.join(",")
	sth=$dbh.prepare("insert into page values (?,?,?)")
	sth.execute(url,title,temp)
	$tempContent.clear

	$hasVisitedUrl.store(url,title)
	if $hasVisitedUrl.size==10
		exit(0)
	end
end
threadNums=10
threadNums.times do
	threads<<Thread.new do
			until $unVisitUrl.empty?
				url=$unVisitUrl.pop(true)
				search(url)
			end	
	end
end
threads.each{|t| t.join}
