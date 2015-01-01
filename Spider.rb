require 'nokogiri'
require 'open-uri'
require 'rubygems'
require 'mysql'
require 'dbi'
require 'thread'


$unVisitUrl=Queue.new      #存放还未被访问的url队列
$unVisitUrl.push("http://www.baidu.com/s?wd=ruby")   	#首先把要搜索的内容放到队列中去(ruby)
$hasVisitedUrl=Hash.new 	#将已经搜索过的url放到一个hashmap中
$tempContent=[] 	#该数组用来存放从页面中得到的标题
$id=1 		#在向related表中添加数据时用来当做判断条件的id号
$dbh=DBI.connect("DBI:Mysql:SpiderDb:localhost","root","lyp")
threads=[]	#线程数组
def search(url)
	page=Nokogiri::HTML(open(url))
	title=page.css('title').text 	#get  current page's title
	pageContent=page.css('div#content_left h3') 	#get current page's content
	relatedTitle=page.css('div#rs th') 		#get related search title
	relatedUrl=page.css('div#rs a') 		#get current page's related search url

	relatedTitle.each do |relatedTitle|	#首先把本页的url和相关搜索的标题放到related表中
		str=relatedTitle.text.strip
		sth1=$dbh.prepare("insert into related (url,entryName) values (?,?)")
		sth1.execute(url,str)
	end
	relatedUrl.each do |relatedUrl|		#再把相关搜索的url放到related表中（根据id找对应的标题）
		str='http://www.baidu.com'+relatedUrl['href']
		$unVisitUrl.push(str)
		sth2=$dbh.prepare("update related set entryUrl=? where id=?")
		sth2.execute(str,$id)
		$id+=1
	end
	pageContent.each do |pageContent|		#得到本页的所以标题
		$tempContent<<pageContent.text.strip		#将标题处理过后放入到这个数组中
	end
	temp=$tempContent.join(",")		#将数组转换为字符串添加到page表中
	sth=$dbh.prepare("insert into page values (?,?,?)")
	sth.execute(url,title,temp)
	$tempContent.clear		#将这个临时数组清空，准备处理下一个url的数据

	$hasVisitedUrl.store(url,title)	#一个判断用于设定查找条数
	if $hasVisitedUrl.size==10
		exit(0)
	end
end
#设定了10个线程
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
