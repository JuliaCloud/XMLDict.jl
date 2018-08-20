using XMLDict
using Test
using JSON


function xdict(xml)
    for (n,v) in xml_dict(xml; strip_text=true)
        if !isa(n, Symbol)
            return v
        end
    end
end

function json_dump(dict)
    nodejs = something(Compat.Sys.which("node"), Compat.Sys.which("nodejs"))
    cmd = ```
        xargs -0 $nodejs -e "
            var o = JSON.parse(process.argv[1]);
            var u = require('util');
            console.log(u.inspect(o, {depth: null, colors: true}));"
    ```
    open(cmd, "w", stdout) do io
        write(io, json(dict))
    end
end


xml1 = """
<CreateQueueResponse>
    <CreateQueueResult>
        <QueueUrl flavour="orange">
            http://queue.amazonaws.com/123456789012/testQueue
        </QueueUrl>
    </CreateQueueResult>
    <ResponseMetadata>
        <RequestId>
            7a62c49f-347e-4fc4-9331-6e8e7a96aa73
        </RequestId>
    </ResponseMetadata>
</CreateQueueResponse>
"""

@test parse_xml(xml1)["CreateQueueResult"]["QueueUrl"][""] ==
      "http://queue.amazonaws.com/123456789012/testQueue"

@test haskey(parse_xml(xml1), "CreateQueueResult")
@test !haskey(parse_xml(xml1), "Foo")
@test haskey(parse_xml(xml1)["CreateQueueResult"], "QueueUrl")
@test !haskey(parse_xml(xml1)["CreateQueueResult"], "Foo")

@test get(parse_xml(xml1)["CreateQueueResult"], "Foo", "Bar") == "Bar"

@test xdict(xml1)["CreateQueueResult"]["QueueUrl"][""] ==
      "http://queue.amazonaws.com/123456789012/testQueue"

@test parse_xml(xml1)["CreateQueueResult"]["QueueUrl"][:flavour] == "orange"

@test xdict(xml1)["CreateQueueResult"]["QueueUrl"][:flavour] == "orange"


xml2 = """
<GetUserResponse xmlns="https://iam.amazonaws.com/doc/2010-05-08/">
  <GetUserResult>
    <User>
      <PasswordLastUsed>2015-12-23T22:45:36Z</PasswordLastUsed>
      <Arn>arn:aws:iam::012541411202:root</Arn>
      <UserId>012541411202</UserId>
      <CreateDate>2015-09-15T01:07:23Z</CreateDate>
    </User>
  </GetUserResult>
  <ResponseMetadata>
    <RequestId>837446c9-abaf-11e5-9f63-65ae4344bd73</RequestId>
  </ResponseMetadata>
</GetUserResponse>
"""

@test parse_xml(xml2)["GetUserResult"]["User"]["Arn"] == 
      "arn:aws:iam::012541411202:root"

@test xdict(xml2)["GetUserResult"]["User"]["Arn"] == 
      "arn:aws:iam::012541411202:root"


xml3 = """
<GetQueueAttributesResponse>
  <GetQueueAttributesResult>
    <Attribute>
      <Name>ReceiveMessageWaitTimeSeconds</Name>
      <Value>2</Value>
    </Attribute>
    <Attribute>
      <Name>VisibilityTimeout</Name>
      <Value>30</Value>
    </Attribute>
    <Attribute>
      <Name>ApproximateNumberOfMessages</Name>
      <Value>0</Value>
    </Attribute>
    <Attribute>
      <Name>ApproximateNumberOfMessagesNotVisible</Name>
      <Value>0</Value>
    </Attribute>
    <Attribute>
      <Name>CreatedTimestamp</Name>
      <Value>1286771522</Value>
    </Attribute>
    <Attribute>
      <Name>LastModifiedTimestamp</Name>
      <Value>1286771522</Value>
    </Attribute>
    <Attribute>
      <Name>QueueArn</Name>
      <Value>arn:aws:sqs:us-east-1:123456789012:qfoo</Value>
    </Attribute>
    <Attribute>
      <Name>MaximumMessageSize</Name>
      <Value>8192</Value>
    </Attribute>
    <Attribute>
      <Name>MessageRetentionPeriod</Name>
      <Value>345600</Value>
    </Attribute>
  </GetQueueAttributesResult>
  <ResponseMetadata>
    <RequestId>1ea71be5-b5a2-4f9d-b85a-945d8d08cd0b</RequestId>
  </ResponseMetadata>
</GetQueueAttributesResponse>
"""

let xml = parse_xml(xml3)
    d = Dict(a["Name"] => a["Value"] for a in xml["GetQueueAttributesResult"]["Attribute"])

    @test d["MessageRetentionPeriod"] == "345600"
    @test d["CreatedTimestamp"] == "1286771522"
end

let xml = xdict(xml3)
    d = Dict(a["Name"] => a["Value"] for a in xml["GetQueueAttributesResult"]["Attribute"])

    @test d["MessageRetentionPeriod"] == "345600"
    @test d["CreatedTimestamp"] == "1286771522"
end

xml4 = """
<?xml version="1.0" encoding="UTF-8"?>
<ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01">
  <Owner>
    <ID>bcaf1ffd86f461ca5fb16fd081034f</ID>
    <DisplayName>webfile</DisplayName>
  </Owner>
  <Buckets>
    <Bucket>
      <Name>quotes</Name>
      <CreationDate>2006-02-03T16:45:09.000Z</CreationDate>
    </Bucket>
    <Bucket>
      <Name>samples</Name>
      <CreationDate>2006-02-03T16:41:58.000Z</CreationDate>
    </Bucket>
  </Buckets>
</ListAllMyBucketsResult>
"""

@test [b["Name"] for b in parse_xml(xml4)["Buckets"]["Bucket"]] == ["quotes", "samples"]

@test [b["Name"] for b in xdict(xml4)["Buckets"]["Bucket"]] == ["quotes", "samples"]

xml5 = """
<?xml version="1.0"?>
<ListDomainsResponse>
  <ListDomainsResult foobar="Hello">
    <DomainName>Domain1</DomainName>
    <DomainName>Domain2</DomainName>
    <NextToken>TWV0ZXJpbmdUZXN0RG9tYWluMS0yMDA3MDYwMTE2NTY=</NextToken>
  </ListDomainsResult>
  <ResponseMetadata>
    <RequestId>eb13162f-1b95-4511-8b12-489b86acfd28</RequestId>
    <BoxUsage>0.0000219907</BoxUsage>
  </ResponseMetadata>
</ListDomainsResponse>
"""

@test parse_xml(xml5)["ListDomainsResult"][:foobar] == "Hello"

@test xdict(xml5)["ListDomainsResult"][:foobar] == "Hello"


xml6 = """
<?xml version="1.0" encoding="UTF-8"?>
<bookstore brand="amazon">
  <book category="COOKING" tag="first">
    <title lang="en">
        Everyday Italian
    </title>
    <author>Giada De Laurentiis</author>
    <year>2005</year>
    <price>30.00</price>
    <Extract copyright="NA">The <b>bold</b> word is <b><i>not</i></b> <i>italic</i>.</Extract>
  </book>
  <book category="CHILDREN">
    <title lang="en">Harry Potter</title>
    <author>J K. Rowling</author>
    <year>2005</year>
    <price>29.99</price>
    <foo><![CDATA[<sender>John Smith</sender>]]></foo>
    <extract><p>Click <a href="foobar.com">right <b>here</b></a> for foobar.</p><b>Bold</b><p>Para2</p></extract>
  </book>
  <metadata>
       <foo>hello!</foo>
  </metadata>
</bookstore>
"""
#json_dump(xml_dict(xml6; strip_text=true))


xml7="""
<?xml version="1.0"?>
<catalog>
   <book id="bk101">
      <author>Gambardella, Matthew</author>
      <title>XML Developer's Guide</title>
      <genre>Computer</genre>
      <price>44.95</price>
      <publish_date>2000-10-01</publish_date>
      <description>An in-depth look at creating applications 
      with XML.</description>
   </book>
   <book id="bk102">
      <author>Ralls, Kim</author>
      <title>Midnight Rain</title>
      <genre>Fantasy</genre>
      <price>5.95</price>
      <publish_date>2000-12-16</publish_date>
      <description>A former architect battles corporate zombies, 
      an evil sorceress, and her own childhood to become queen 
      of the world.</description>
   </book>
   <book id="bk103">
      <author>Corets, Eva</author>
      <title>Maeve Ascendant</title>
      <genre>Fantasy</genre>
      <price>5.95</price>
      <publish_date>2000-11-17</publish_date>
      <description>After the collapse of a nanotechnology 
      society in England, the young survivors lay the 
      foundation for a new society.</description>
   </book>
   <book id="bk104">
      <author>Corets, Eva</author>
      <title>Oberon's Legacy</title>
      <genre>Fantasy</genre>
      <price>5.95</price>
      <publish_date>2001-03-10</publish_date>
      <description>In post-apocalypse England, the mysterious 
      agent known only as Oberon helps to create a new life 
      for the inhabitants of London. Sequel to Maeve 
      Ascendant.</description>
   </book>
   <book id="bk105">
      <author>Corets, Eva</author>
      <title>The Sundered Grail</title>
      <genre>Fantasy</genre>
      <price>5.95</price>
      <publish_date>2001-09-10</publish_date>
      <description>The two daughters of Maeve, half-sisters, 
      battle one another for control of England. Sequel to 
      Oberon's Legacy.</description>
   </book>
   <book id="bk106">
      <author>Randall, Cynthia</author>
      <title>Lover Birds</title>
      <genre>Romance</genre>
      <price>4.95</price>
      <publish_date>2000-09-02</publish_date>
      <description>When Carla meets Paul at an ornithology 
      conference, tempers fly as feathers get ruffled.</description>
   </book>
   <book id="bk107">
      <author>Thurman, Paula</author>
      <title>Splish Splash</title>
      <genre>Romance</genre>
      <price>4.95</price>
      <publish_date>2000-11-02</publish_date>
      <description>A deep sea diver finds true love twenty 
      thousand leagues beneath the sea.</description>
   </book>
   <book id="bk108">
      <author>Knorr, Stefan</author>
      <title>Creepy Crawlies</title>
      <genre>Horror</genre>
      <price>4.95</price>
      <publish_date>2000-12-06</publish_date>
      <description>An anthology of horror stories about roaches,
      centipedes, scorpions  and other insects.</description>
   </book>
   <book id="bk109">
      <author>Kress, Peter</author>
      <title>Paradox Lost</title>
      <genre>Science Fiction</genre>
      <price>6.95</price>
      <publish_date>2000-11-02</publish_date>
      <description>After an inadvertant trip through a Heisenberg
      Uncertainty Device, James Salway discovers the problems 
      of being quantum.</description>
   </book>
   <book id="bk110">
      <author>O'Brien, Tim</author>
      <title>Microsoft .NET: The Programming Bible</title>
      <genre>Computer</genre>
      <price>36.95</price>
      <publish_date>2000-12-09</publish_date>
      <description>Microsoft's .NET initiative is explored in 
      detail in this deep programmer's reference.</description>
   </book>
   <book id="bk111">
      <author>O'Brien, Tim</author>
      <title>MSXML3: A Comprehensive Guide</title>
      <genre>Computer</genre>
      <price>36.95</price>
      <publish_date>2000-12-01</publish_date>
      <description>The Microsoft MSXML3 parser is covered in 
      detail, with attention to XML DOM interfaces, XSLT processing, 
      SAX and more.</description>
   </book>
   <book id="bk112">
      <author>Galos, Mike</author>
      <title>Visual Studio 7: A Comprehensive Guide</title>
      <genre>Computer</genre>
      <price>49.95</price>
      <publish_date>2001-04-16</publish_date>
      <description>Microsoft Visual Studio 7 is explored in depth,
      looking at how Visual Basic, Visual C++, C#, and ASP+ are 
      integrated into a comprehensive development 
      environment.</description>
   </book>
</catalog>
"""


xml8="""
<?xml version="1.0"?>
<catalog>
   <product description="Cardigan Sweater" product_image="cardigan.jpg">
      <catalog_item gender="Men's">
         <item_number>QWZ5671</item_number>
         <price>39.95</price>
         <size description="Medium">
            <color_swatch image="red_cardigan.jpg">Red</color_swatch>
            <color_swatch image="burgundy_cardigan.jpg">Burgundy</color_swatch>
         </size>
         <size description="Large">
            <color_swatch image="red_cardigan.jpg">Red</color_swatch>
            <color_swatch image="burgundy_cardigan.jpg">Burgundy</color_swatch>
         </size>
      </catalog_item>
      <catalog_item gender="Women's">
         <item_number>RRX9856</item_number>
         <price>42.50</price>
         <size description="Small">
            <color_swatch image="red_cardigan.jpg">Red</color_swatch>
            <color_swatch image="navy_cardigan.jpg">Navy</color_swatch>
            <color_swatch image="burgundy_cardigan.jpg">Burgundy</color_swatch>
         </size>
         <size description="Medium">
            <color_swatch image="red_cardigan.jpg">Red</color_swatch>
            <color_swatch image="navy_cardigan.jpg">Navy</color_swatch>
            <color_swatch image="burgundy_cardigan.jpg">Burgundy</color_swatch>
            <color_swatch image="black_cardigan.jpg">Black</color_swatch>
         </size>
         <size description="Large">
            <color_swatch image="navy_cardigan.jpg">Navy</color_swatch>
            <color_swatch image="black_cardigan.jpg">Black</color_swatch>
         </size>
         <size description="Extra Large">
            <color_swatch image="burgundy_cardigan.jpg">Burgundy</color_swatch>
            <color_swatch image="black_cardigan.jpg">Black</color_swatch>
         </size>
      </catalog_item>
   </product>
</catalog>
"""

xml9 = """
<?xml version="1.0"?>
<table border="1" frame="border">
  <tbody>
    <tr>
      <td>
        <code>00 00 FE FF</code>
      </td>
      <td>UCS-4, big-endian machine (1234 order)</td>
    </tr>
    <tr>
      <td>
        <code>FF FE 00 00</code>
      </td>
      <td>UCS-4, little-endian machine (4321 order)</td>
    </tr>
    <tr>
      <td>
        <code>00 00 FF FE</code>
      </td>
      <td>UCS-4, unusual octet order (2143)</td>
    </tr>
    <tr>
      <td>
        <code>FE FF 00 00</code>
      </td>
      <td>UCS-4, unusual octet order (3412)</td>
    </tr>
    <tr>
      <td>
        <code>FE FF ## ##</code>
      </td>
      <td>UTF-16, big-endian</td>
    </tr>
    <tr>
      <td>
        <code>FF FE ## ##</code>
      </td>
      <td>UTF-16, little-endian</td>
    </tr>
    <tr>
      <td>
        <code>EF BB BF</code>
      </td>
      <td>UTF-8</td>
    </tr>
  </tbody>
</table>
"""

xml10 = read("REC-xml-20081126.xml", String)

function normalise_xml(xml)
    cmd = `bash -c 'xmllint --noent --format --nocdata - | sed s/\ xmlns=\".*\"//g'`
    @static if VERSION >= v"0.7.0-DEV.3427"
        p = open(cmd, "r+")
        write(p, xml)
        close(p.in)
        return read(p, String)
    else
        o, i, p = readandwrite(cmd)
        write(i, xml)
        close(i)
        return read(o, String)
    end
end


for xml in [xml1, xml2, xml3, xml4, xml5, xml6, xml7, xml8, xml9, xml10]

    if normalise_xml(xml) != normalise_xml(XMLDict.dict_xml(xml_dict(xml)))

        println(normalise_xml(XMLDict.dict_xml(xml_dict(xml))))

        json_dump(xml_dict(xml))

        # For interactive use on macOS
        #write("/tmp/a", normalise_xml(xml))
        #write("/tmp/b", normalise_xml(XMLDict.dict_xml(xml_dict(xml))))
        #run(`opendiff /tmp/a /tmp/b`)
    end


    @test normalise_xml(xml) == normalise_xml(XMLDict.dict_xml(xml_dict(xml)))

end


