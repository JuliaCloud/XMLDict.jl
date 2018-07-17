#==============================================================================#
# XMLDict.jl
#
# Copyright Sam O'Connor 2015 - All rights reserved
#==============================================================================#


__precompile__()


module XMLDict

export parse_xml, xml_dict


using EzXML
using DataStructures
using Base.Iterators
using IterTools
using Compat


#-------------------------------------------------------------------------------
# Associative type wrapper.
#-------------------------------------------------------------------------------

mutable struct XMLDictElement <: AbstractDict{Union{String,Symbol},Any}
    x
    doc
    g
end

wrap(x, doc) = XMLDictElement(x, doc, nothing)
wrap(l::Vector, doc) = [wrap(i, doc) for i in l]

Base.get(x::XMLDictElement, k, d=nothing) = XMLDict.get(x.x, x.doc, k, d)

Base.keys(x::XMLDictElement) = XMLDict.keys(x.x)
Base.length(x::XMLDictElement) = length(collect(keys(x)))

function Base.start(x::XMLDictElement)
    x.g = (Pair{Union{String,Symbol},Any}(n, (get(x, n))) for n in keys(x))
    start(x.g)
end
Base.done(x::XMLDictElement, s) = done(x.g, s)
Base.next(x::XMLDictElement, s) = next(x.g, s)

xml_dict(x, args...; options...) = xml_dict(x.x, args...; options...)

Base.show(io::IO, x::XMLDictElement) = show(io, x.x)


#-------------------------------------------------------------------------------
# XML Parsing.
#-------------------------------------------------------------------------------


# Parse "xml" string into EzXML.Document object.

function parse_xml(xml::AbstractString)
    doc = parsexml(xml)
    return wrap(doc, doc)
end


#-------------------------------------------------------------------------------
# Dynamic Associative Implementation for XMLElement
#-------------------------------------------------------------------------------


function XMLDict.keys(x::EzXML.Node)
    children = distinct(nodename(c) for c in eachelement(x))
    attribs = (Symbol(nodename(c)) for c in eachattribute(x))
    return Iterators.flatten((children, attribs))
end
XMLDict.keys(x::EzXML.Document) = keys(root(x))


# Get sub-elements that match tag.
# For leaf-nodes return element content (text).

function XMLDict.get(x::EzXML.Node, doc::EzXML.Document, tag::AbstractString, default)

    if tag == ""
        return strip(nodecontent(x))
    end

    if !haselement(x)
        return default
    end
    l = filter(el->nodename(el) == tag, elements(x))
    if isempty(l)
        return default
    end
    if countelements(l[1]) == countattributes(l[1]) == 0
        l = map(strip∘nodecontent, l)
    else
        l = wrap(l, doc)
    end
    return length(l) == 1 ? l[1] : l
end


# Get element attribute by "name".

function XMLDict.get(x::EzXML.Node, doc::EzXML.Document, name::Symbol, default)
    s = string(name)
    haskey(x, s) ? x[s] : default
end


# Wrapper for EzXML.Document.

function XMLDict.get(x::EzXML.Document, doc::EzXML.Document, tag, default)
    return XMLDict.get(root(x), doc, tag, default)
end



#-------------------------------------------------------------------------------
# Convert entire XMLDocument to OrderedDict...
#-------------------------------------------------------------------------------


# Return Dict representation of "xml" string.

function xml_dict(xml::AbstractString, dict_type::Type=OrderedDict; options...)
    doc = parse_xml(xml)
    r = xml_dict(doc, dict_type; options...)
    return r
end


# Return Dict representation of EzXML.Document.

function xml_dict(xml::EzXML.Document, dict_type::Type=OrderedDict; options...)
    r = dict_type()
    r[:version] = version(xml)
    try
        r[:encoding] = encoding(xml)
    end
    r[nodename(root(xml))] = xml_dict(root(xml), dict_type; options...)
    r
end


# Does this node have any text?

is_text(x::EzXML.Node) = istext(x) || iscdata(x)
function is_empty(x::EzXML.Node)
    c = nodecontent(x)
    return isempty(c) || all(isspace, c)
end
has_text(x::EzXML.Node) = is_text(x) && !is_empty(x)


# Return Dict representation of XMLElement.

function xml_dict(x::EzXML.Node, dict_type::Type=OrderedDict; strip_text=false)

    # Copy element attributes into dict...
    r = dict_type()
    for a in eachattribute(x)
        r[Symbol(nodename(a))] = nodecontent(a)
    end

    # Check for non-empty text nodes under this element...
    element_has_text = any(has_text, eachnode(x))

    # Check for non-contiguous repetition of sub-element tags...
    element_has_mixed_tags = false
    tags = []
    for c in eachelement(x)
        tag = nodename(c)
        if isempty(tags) || tag != tags[end]
            if tag in tags
                element_has_mixed_tags = true
                break
            end
            push!(tags, tag)
        end
    end

    # The empty-string key holds a vector of sub-elements.
    # This is necessary when grouping sub-elements would alter ordering...
    if element_has_text || element_has_mixed_tags
        r[""] = Any[]
    end

    for c in eachnode(x)

        if iselement(c)

            # Get name and sub-dict for sub-element...
            n = nodename(c)
            v = xml_dict(c, dict_type; strip_text=strip_text)

            if haskey(r, "")

                # If this is a text element, embed sub-dict in text vector...
                # "The <b>bold</b> tag" == ["The", Dict("b" => "bold"), "tag"]
                push!(r[""], dict_type(n => v))

            elseif haskey(r, n)

                # Collect sub-elements with same tag into a vector...
                # "<item>foo</item><item>bar</item>" == "item" => ["foo", "bar"]
                a = isa(r[n], Array) ? r[n] : Any[r[n]]
                push!(a, v)
                r[n] = a
            else
                r[n] = v
            end

        elseif is_text(c) && haskey(r, "")
            push!(r[""], nodecontent(c))
        end
    end

    # Collapse leaf-node vectors containing only text...
    if haskey(r, "")
        v = r[""]

        # If the vector contains a single text element, collapse the vector...
        if length(v) == 1 && isa(v[1], AbstractString)
            if strip_text
                v[1] = strip(v[1])
            end
            r[""] = v[1]

            # If "r" contains no other keys, collapse the "" key...
            if length(r) == 1
                r = r[""]
            end
        end
    end

    return r
end



#-------------------------------------------------------------------------------
# Convert Dict (produced by xml_dict) back to an XML string.
#
# dict_xml(xml_dict(xml_string)) ~= xml_string
#-------------------------------------------------------------------------------


function dict_xml(root::AbstractDict)
    string("<?xml", attr_xml(root), "?>\n", node_xml(root))
end

if VERSION >= v"0.7.0-DEV.1393" # filter is passed one pair instead of two arguments
    attrs(node::AbstractDict) = filter(pair->isa(first(pair), Symbol), node)
    nodes(node::AbstractDict) = filter(pair->!isa(first(pair), Symbol), node)
else
    attrs(node::AbstractDict) = filter((n,v)->isa(n, Symbol), node)
    nodes(node::AbstractDict) = filter((n,v)->!isa(n, Symbol), node)
end

function attr_xml(node::AbstractDict)
    join([" $n=\"$v\"" for (n,v) in attrs(node)])
end

attr_xml(node) = ""


node_xml(node) = join([node_xml(n,v) for (n,v) in nodes(node)])

function node_xml(name::AbstractString, value::AbstractArray)
    value_xml(name != "" ? [Dict(name=>i) for i in value] : value)
end

function node_xml(name::AbstractString, node)
    a = attr_xml(node)
    v = value_xml(node)
    name == "" ? v : string("<", name, a, v == "" ? "/>" : ">$v</$name>")
end


value_xml(value::AbstractDict) = node_xml(value)

value_xml(value::AbstractArray) = join(map(value_xml, value))

value_xml(value::AbstractString) = escape(value)


function escape(s::AbstractString)
    p = ccall((:xmlEncodeEntitiesReentrant, EzXML.libxml2), Ptr{UInt8},
              (Ptr{Cvoid}, Cstring), C_NULL, s)
    p == C_NULL ? "" : unsafe_string(p)
end



end # module XMLDict



#==============================================================================#
# End of file
#==============================================================================#
