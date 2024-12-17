@# Included from rosidl_generator_c/resource/idl__description.c.em
@{
from rosidl_generator_c import escape_string
from rosidl_generator_c import idl_structure_type_to_c_include_prefix
from rosidl_generator_c import type_hash_to_c_definition
from rosidl_parser.definition import NamespacedType
from rosidl_generator_type_description import FIELD_TYPE_ID_TO_NAME
from rosidl_generator_type_description import GET_DESCRIPTION_FUNC
from rosidl_generator_type_description import GET_HASH_FUNC
from rosidl_generator_type_description import GET_INDIVIDUAL_SOURCE_FUNC
from rosidl_generator_type_description import GET_SOURCES_FUNC

def typename_to_c(typename):
  return typename.replace('/', '__')

def static_seq_n(varname, n):
  """Statically define a runtime Sequence or String type."""
  if n > 0:
    return f'{{{varname}, {n}, {n}}}'
  return '{NULL, 0, 0}'

def static_seq(varname, values):
  """Statically define a runtime Sequence or String type."""
  if values:
    return f'{{{varname}, {len(values)}, {len(values)}}}'
  return '{NULL, 0, 0}'

def utf8_encode(value_string):
  from rosidl_generator_c import escape_string
  # Slice removes the b'' from the representation.
  return escape_string(repr(value_string.encode('utf-8'))[2:-1])

implicit_type_names = set(td['type_description']['type_name'] for td, _ in implicit_type_descriptions)
includes = set()
toplevel_msg, _ = toplevel_type_description

for referenced_td in toplevel_msg['referenced_type_descriptions']:
    if referenced_td['type_name'] in implicit_type_names:
        continue
    names = referenced_td['type_name'].split('/')
    _type = NamespacedType(names[:-1], names[-1])
    include_prefix = idl_structure_type_to_c_include_prefix(_type, 'detail')
    includes.add(include_prefix + '__functions.h')

full_type_descriptions = [toplevel_type_description] + implicit_type_descriptions
full_type_names = [t['type_description']['type_name'] for t, _ in full_type_descriptions]
all_type_descriptions = [toplevel_msg['type_description']] + toplevel_msg['referenced_type_descriptions']

toplevel_encoding = type_source_file.suffix[1:]
with open(type_source_file, 'r', encoding='utf-8') as f:
  raw_source_content = f.read()
}@
@
#include <assert.h>
#include <string.h>

// Include directives for referenced types
@[for header_file in includes]@
#include "@(header_file)"
@[end for]@

@#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
@# Cache expected hashes for externally referenced types, for error checking
// Hashes for external referenced types
#ifndef NDEBUG
@[for referenced_type_description in toplevel_msg['referenced_type_descriptions']]@
@{
type_name = referenced_type_description['type_name']
c_typename = type_name.replace('/', '__')
}@
@[  if type_name not in full_type_names]@
static const rosidl_type_hash_t @(c_typename)__EXPECTED_HASH = @(type_hash_to_c_definition(hash_lookup[type_name]));
@[  end if]@
@[end for]@
#endif
@#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

@#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
@# Names for all types
@[for itype_description in all_type_descriptions]@
static char @(typename_to_c(itype_description['type_name']))__TYPE_NAME[] = "@(itype_description['type_name'])";
@[end for]@
@#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

@#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
@# Define individual raw sources
@[if raw_source_content]@
static char toplevel_type_raw_source[] =@
@[  for line in raw_source_content.splitlines()[:-1]]
  "@(utf8_encode(line))\n"@
@[  end for]
  "@(utf8_encode(raw_source_content.splitlines()[-1]))";
@[end if]@

static char @(toplevel_encoding)_encoding[] = "@(toplevel_encoding)";
@[if implicit_type_descriptions]@
static char implicit_encoding[] = "implicit";
@[end if]@

// Define all individual source functions
@[for type_description_msg, interface_type in full_type_descriptions]@
@{
itype_description = type_description_msg['type_description']
td_typename = itype_description['type_name']
td_c_typename = typename_to_c(td_typename)
if td_typename in implicit_type_names:
  encoding = 'implicit'
  contents_var = None
  contents = None
else:
  encoding = toplevel_encoding
  contents_var = 'toplevel_type_raw_source'
  contents = raw_source_content
}@

const rosidl_runtime_c__type_description__TypeSource *
@(td_c_typename)__@(GET_INDIVIDUAL_SOURCE_FUNC)(
  const rosidl_@(interface_type)_type_support_t * type_support)
{
  (void)type_support;
  static const rosidl_runtime_c__type_description__TypeSource source = {
    @(static_seq(f'{td_c_typename}__TYPE_NAME', td_typename)),
    @(static_seq(f'{encoding}_encoding', encoding)),
    @(static_seq(contents_var, contents)),
  };
  return &source;
}
@[end for]@
@#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
