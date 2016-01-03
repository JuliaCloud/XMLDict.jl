# XMLDict.jl

XMLDict implements an Associative interface (`get()`, `getindex()`,
`haskey()`) for the XMLDocument and XMLElement objects returned by
[LightXML.jl](https://github.com/JuliaLang/LightXML.jl).


## Examples

Extract the content of a single tag...

```julia
xml = parse_xml("""
<CreateQueueResponse>
    <CreateQueueResult>
        <QueueUrl>http://queue.amazonaws.com/123456789012/testQueue</QueueUrl>
    </CreateQueueResult>
</CreateQueueResponse>
""")

@test xml["CreateQueueResult"]["QueueUrl"] == "http://queue.amazonaws.com/123456789012/testQueue"
```

Extract an attribute from a tag by using a `:symbol` as key...

```julia
xml = parse_xml("""
<bookstore>
  <book category="COOKING" tag="first"/>
<bookstore>

@test xml["bookstore"]["book"][:category] == "COOKING"
```


Extract a list of tag content...

```julia
xml = parse_xml("""
<ListAllMyBucketsResult>
  <Buckets>
    <Bucket><Name>quotes</Name><CreationDate>2006-02-03T16:45:09.000Z</CreationDate></Bucket>
    <Bucket><Name>samples</Name><CreationDate>2006-02-03T16:41:58.000Z</CreationDate></Bucket>
  </Buckets>
</ListAllMyBucketsResult>
""")

@test [b["Name"] for b in xml["Buckets"]["Bucket"]] == ["quotes", "samples"]
```

Extract a dictionary of `<Name>`, `<Value>` tags content...

```julia

xml = parse_xml("""
<GetQueueAttributesResponse>
  <GetQueueAttributesResult>
    <Attribute><Name>VisibilityTimeout</Name><Value>30</Value></Attribute>
    <Attribute><Name>CreatedTimestamp</Name><Value>1286771522</Value></Attribute>
    <Attribute><Name>MaximumMessageSize</Name><Value>8192</Value></Attribute>
    <Attribute><Name>MessageRetentionPeriod</Name><Value>345600</Value></Attribute>
  </GetQueueAttributesResult>
</GetQueueAttributesResponse>
""")

d = [a["Name"] => a["Value"] for a in xml["GetQueueAttributesResult"]["Attribute"]]

Dict with 4 entries:
  "MessageRetentionPeriod" => "345600"
  "MaximumMessageSize"     => "8192"
  "VisibilityTimeout"      => "30"
  "CreatedTimestamp"       => "1286771522"
```


Convert entire XML document to a Julia Dict...

```xml
xml="""
<?xml version="1.0" encoding="UTF-8"?>
<bookstore brand="amazon">
  <book category="COOKING" tag="first">
    <title lang="en">
        Everyday Italian
    </title>
    <author>Giada De Laurentiis</author>
    <year>2005</year>
    <price>30.00</price>
    <extract copyright="NA">The <b>bold</b> word is <b><i>not</i></b> <i>italic</i>.</extract>
  </book>
  <book category="CHILDREN">
    <title lang="en">Harry Potter</title>
    <author>J K. Rowling</author>
    <year>2005</year>
    <price>29.99</price>
    <foo><![CDATA[<sender>John Smith</sender>]]></foo>
    <extract>Click <a href="foobar.com">right <b>here</b></a> for foobar.</extract>
  </book>
  <metadata>
       <foo>hello!</foo>
  </metadata>
</bookstore>
"""
```

```julia
xml_string = xml_dict(xml)

Dict(
    :version=>"1.0",
    :encoding=>"UTF-8",
    "bookstore"=>Dict(
        :brand=>"amazon",
        "book"=>[
            Dict(
                :category=>"COOKING",
                :tag=>"first",
                "title"=>Dict(:lang=>"en",:text=>"Everyday Italian"),
                "author"=>"Giada De Laurentiis",
                "year"=>"2005",
                "price"=>"30.00",
                "extract"=>Dict(
                    :copyright=>"NA",
                    :text=>["The ",Dict("b"=>"bold")," word is ", Dict("b"=>Dict("i"=>"not"))," ",Dict("i"=>"italic"),"."])
            ),
            Dict(
                :category=>"CHILDREN",
                "title"=>Dict(:lang=>"en",:text=>"Harry Potter"),
                "author"=>"J K. Rowling",
                "year"=>"2005",
                "price"=>"29.99",
                "foo"=>"<sender>John Smith</sender>",
                "extract"=>["Click ",Dict("a"=>Dict(:href=>"foobar.com",:text=>Any["right ",Dict("b"=>"here")]))," for foobar."]
            )],
        "metadata"=>Dict("foo"=>"hello!")
    )
)
```
