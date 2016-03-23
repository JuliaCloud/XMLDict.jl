#==============================================================================#
# XMLDict.jl
#
# Copyright Sam O'Connor 2015 - All rights reserved
#==============================================================================#


__precompile__()


module XMLDict

export parse_xml, xml_dict


using LightXML
using DataStructures



#-------------------------------------------------------------------------------
# Associative type wrapper.
#-------------------------------------------------------------------------------

type XMLDictElement <:Associative{Union{AbstractString,Symbol},AbstractString}
    x
    doc
end

wrap(x, doc) = XMLDictElement(x, doc)
wrap(l::Vector, doc) = [wrap(i, doc) for i in l]

Base.get(x::XMLDictElement, args...) = XMLDict.get(x.x, x.doc, args...)

xml_dict(x, args...; options...) = xml_dict(x.x, args...; options...)

# FIXME should no be needed for Julia >= 5.0
# Old replutil.jl calls showdict() ditectly for Accociatve !!
# https://github.com/JuliaLang/julia/commit/4706184a424eda72aa802f465c7f45c5545143e0#diff-b662111ca543844cd53139f7a6ffa89dL45
Base.writemime(io::IO, ::MIME"text/plain", x::XMLDictElement) = show(io, x)

Base.show(io::IO, x::XMLDictElement) = show(io, x.x)



#-------------------------------------------------------------------------------
# XML Parsing.
#-------------------------------------------------------------------------------


# Parse "xml" string into LightXML.XMLDocument object.

function parse_xml(xml::AbstractString)
    doc = LightXML.parse_string(xml)
    finalizer(doc, LightXML.free)
    return wrap(doc, doc)
end



#-------------------------------------------------------------------------------
# Dynamic Associative Implementation for XMLElement
#-------------------------------------------------------------------------------


# Get sub-elements that match tag.
# For leaf-nodes return element content (text).

function XMLDict.get(x::XMLElement, doc::XMLDocument, tag::AbstractString, default)

    if tag == ""
        return strip(content(x))
    end

    l = get_elements_by_tagname(x, tag)
    if isempty(l)
        return default
    end
    if isempty(child_elements(l[1])) &&
       isempty(attributes(l[1]))
        l = [strip(content(i)) for i in l]
    else
        l = wrap(l, doc)
    end
    return length(l) == 1 ? l[1] : l
end


# Get element attribute by "name".

function XMLDict.get(x::XMLElement, doc::XMLDocument, name::Symbol, default)
    r = attribute(x, string(name))
    r != nothing ? r : default
end


# Wrapper for XMLDocument.

function XMLDict.get(x::XMLDocument, doc::XMLDocument, tag, default) 
    return XMLDict.get(root(x), doc, tag, default)
end



#-------------------------------------------------------------------------------
# Convert entire XMLDocument to OrderedDict...
#-------------------------------------------------------------------------------


# Return Dict representation of "xml" string.

function xml_dict(xml::AbstractString, dict_type::Type=OrderedDict; options...)
    doc = parse_xml(xml)
    r = xml_dict(doc, dict_type; options...)
    finalize(doc)
    return r
end


# Return Dict representation of XMLDocument.

function xml_dict(xml::XMLDocument, dict_type::Type=OrderedDict; options...)
    r = dict_type()
    r[:version] = version(xml)
    try #FIXME see https://github.com/JuliaLang/LightXML.jl/issues/40
        r[:encoding] = encoding(xml)
    end
    r[name(root(xml))] = xml_dict(root(xml), dict_type; options...)
    r
end


# Does this node have any text?

is_text(x::XMLNode) = is_textnode(x) || is_cdatanode(x)
is_empty(x::XMLNode) = isspace(content(x))
has_text(x::XMLNode) = is_text(x) && !is_empty(x)


# Return Dict representation of XMLElement.

function xml_dict(x::XMLElement, dict_type::Type=OrderedDict; strip_text=false)

    # Copy element attributes into dict...
    r = dict_type()
    for a in attributes(x)
        r[symbol(name(a))] = value(a)
    end

    # Check for non-empty text nodes under this element...
    element_has_text = any(has_text, child_nodes(x))

    # Check for non-contiguous repetition of sub-element tags...
    element_has_mixed_tags = false
    tags = []
    for c in child_elements(x)
        tag = name(c)
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

    for c in child_nodes(x)

        if is_elementnode(c)

            # Get name and sub-dict for sub-element...
            c = XMLElement(c)
            n = name(c)
            v = xml_dict(c,dict_type;strip_text=strip_text)

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
            push!(r[""], content(c))
        end
    end

    # Collapse leaf-node vectors containing only text...
    if haskey(r, "")
        v = r[""]

        # If the vector contains a single text element, collapse the vector...
        if length(v) == 1 && typeof(v[1]) <: AbstractString
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


function dict_xml(root::Associative)
    string("<?xml",attr_xml(root),"?>\n", node_xml(root))
end


attrs(node::Associative) = filter((n,v)->isa(n, Symbol), node)
nodes(node::Associative) = filter((n,v)->!isa(n, Symbol), node)

function attr_xml(node::Associative)
    string([" $n=\"$v\"" for (n,v) in attrs(node)]...)
end

attr_xml(node) = ""


node_xml(node) = string([node_xml(n,v) for (n,v) in nodes(node)]...)

function node_xml(name::AbstractString, value::AbstractArray)
    value_xml(name != "" ? [Dict(name=>i) for i in value] : value)
end

function node_xml(name::AbstractString, node)
    a = attr_xml(node)
    v = value_xml(node)
    name == "" ? v : string("<",name,a,v == "" ? "/>" : ">$v</$name>")
end


value_xml(value::Associative) = node_xml(value)

value_xml(value::AbstractArray) = string([value_xml(v) for v in value]...)

value_xml(value::AbstractString) = escape(value)



import LightXML: Xstr, Xptr, _xcopystr, libxml2

function escape(s::AbstractString)
    p = ccall((:xmlEncodeEntitiesReentrant,libxml2), Xstr, (Xptr, Cstring), C_NULL, s)
    (p != C_NULL ? _xcopystr(p) : "")::AbstractString
end



end # module XMLDict



#==============================================================================#
# End of file
#==============================================================================#
