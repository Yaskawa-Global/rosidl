@# Included from rosidl_generator_c/resource/idl__functions.c.em
@{
from ast import literal_eval
from rosidl_parser.definition import AbstractNestedType
from rosidl_parser.definition import AbstractSequence
from rosidl_parser.definition import AbstractString
from rosidl_parser.definition import AbstractWString
from rosidl_parser.definition import Array
from rosidl_parser.definition import BasicType
from rosidl_parser.definition import AbstractGenericString
from rosidl_parser.definition import NamespacedType
from rosidl_generator_c import basetype_to_c
from rosidl_generator_c import idl_structure_type_sequence_to_c_typename
from rosidl_generator_c import idl_structure_type_to_c_include_prefix
from rosidl_generator_c import idl_structure_type_to_c_typename
from rosidl_generator_c import idl_type_to_c
from rosidl_generator_c import interface_path_to_string
from rosidl_generator_c import value_to_c

message_typename = idl_structure_type_to_c_typename(message.structure.namespaced_type)
array_typename = idl_structure_type_sequence_to_c_typename(
    message.structure.namespaced_type)
}@
@#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
@# Collect necessary include directives for all members
@{
from collections import OrderedDict
includes = OrderedDict()
for member in message.structure.members:
    if isinstance(member.type, AbstractSequence) and isinstance(member.type.value_type, BasicType):
        member_names = includes.setdefault(
            'rosidl_runtime_c/primitives_sequence_functions.h', [])
        member_names.append(member.name)
        continue
    type_ = member.type
    if isinstance(type_, AbstractNestedType):
        type_ = type_.value_type
    if isinstance(type_, AbstractString):
        member_names = includes.setdefault('rosidl_runtime_c/string_functions.h', [])
        member_names.append(member.name)
    elif isinstance(type_, AbstractWString):
        member_names = includes.setdefault(
            'rosidl_runtime_c/u16string_functions.h', [])
        member_names.append(member.name)
    elif isinstance(type_, NamespacedType):
        include_prefix = idl_structure_type_to_c_include_prefix(
          type_, 'detail')
        member_names = includes.setdefault(
            include_prefix + '__functions.h', [])
        member_names.append(member.name)
}@
@#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
@
@#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
@[if includes]@

// Include directives for member types
@[    for header_file, member_names in includes.items()]@
@[        for member_name in member_names]@
// Member `@(member_name)`
@[        end for]@
@[        if header_file in include_directives]@
// already included above
// @
@[        else]@
@{include_directives.add(header_file)}@
@[        end if]@
#include "@(header_file)"
@[    end for]@
@[end if]@
@#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

@#######################################################################
@# message functions
@#######################################################################
bool
@(message_typename)__init(@(message_typename) * msg)
{
  if (!msg) {
    return false;
  }
@{
label_prefix = 'abort_init_'
last_label_index = 0
lines = []
abort_lines = []
for member in message.structure.members:
    lines.append('// ' + member.name)
    if isinstance(member.type, Array):
        if isinstance(member.type.value_type, BasicType):
            if member.has_annotation('default'):
                # set default value for each array element
                for i, default_value in enumerate(literal_eval(member.get_annotation_value('default')['value'])):
                    lines.append('msg->%s[%d] = %s;' % (member.name, i, value_to_c(member.type.value_type, default_value)))
        elif isinstance(member.type.value_type, (AbstractGenericString, NamespacedType)):
            # initialize each array element
            lines.append('for (size_t i = 0; i < %d; ++i) {' % member.type.size)
            lines.append('  if (!%s__init(&msg->%s[i])) {' % (basetype_to_c(member.type.value_type), member.name))
            lines.append('    %s__fini(msg);' % message_typename)
            lines.append('    return false;')
            lines.append('  }')
            lines.append('}')

            if member.has_annotation('default'):
                for i, default_value in enumerate(literal_eval(member.get_annotation_value('default')['value'])):
                    if isinstance(member.type.value_type, AbstractGenericString):
                        lines.append('{')
                        lines.append(
                            '  bool success = %s__assign(&msg->%s[%d], %s);' % \
                            (basetype_to_c(member.type.value_type), member.name, i, value_to_c(member.type.value_type, default_value)))
                        lines.append('  if (!success) {')
                        lines.append('    goto %s%s;' % (label_prefix, last_label_index))
                        abort_lines[0:0] = [
                            '  %s__fini(&msg->%s[%d]);' % (basetype_to_c(member.type.value_type), member.name, i),
                            '%s%d:' % (label_prefix, last_label_index),
                        ]
                        last_label_index += 1
                        lines.append('  }')
                        lines.append('}')

    elif isinstance(member.type, AbstractSequence):
        if not member.has_annotation('default'):
            # initialize the dynamic array with a capacity of zero
            lines.append('if (!%s__init(&msg->%s, 0)) {' % (idl_type_to_c(member.type), member.name))
            lines.append('  %s__fini(msg);' % message_typename)
            lines.append('  return false;')
            lines.append('}')
        else:
            # initialize the dynamic array with the number of default values
            lines.append('{')
            lines.append('  bool success = %s__init(&msg->%s, %d);' % (idl_type_to_c(member.type), member.name, len(literal_eval(member.get_annotation_value('default')['value']))))
            lines.append('  if (!success) {')
            lines.append('    goto %s%d;' % (label_prefix, last_label_index))
            abort_lines[0:0] = [
                '  %s__fini(&msg->%s);' % (idl_type_to_c(member.type), member.name),
                '%s%d:' % (label_prefix, last_label_index),
            ]
            last_label_index += 1
            lines.append('  }')
            lines.append('}')
            # set default value for each array element
            for i, default_value in enumerate(literal_eval(member.get_annotation_value('default')['value'])):
                if isinstance(member.type.value_type, AbstractGenericString):
                    lines.append('{')
                    lines.append(
                        '  bool success = %s__assign(&msg->%s.data[%d], %s);' % \
                        (basetype_to_c(member.type.value_type), member.name, i, value_to_c(member.type.value_type, default_value)))
                    lines.append('  if (!success) {')
                    lines.append('    goto %s%s;' % (label_prefix, last_label_index))
                    abort_lines[0:0] = [
                        '  %s__fini(&msg->%s.data[%d]);' % (basetype_to_c(member.type.value_type), member.name, i),
                        '%s%d:' % (label_prefix, last_label_index),
                    ]
                    last_label_index += 1
                    lines.append('  }')
                    lines.append('}')
                else:
                    lines.append('msg->%s.data[%d] = %s;' % (member.name, i, value_to_c(member.type.value_type, default_value)))

    elif isinstance(member.type, NamespacedType):
            # initialize the sub message
            lines.append('if (!%s__init(&msg->%s)) {' % (basetype_to_c(member.type), member.name))
            lines.append('  %s__fini(msg);' % message_typename)
            lines.append('  return false;')
            lines.append('}')
        # no default value for nested messages yet

    elif isinstance(member.type, AbstractGenericString):
        lines.append('if (!%s__init(&msg->%s)) {' % (basetype_to_c(member.type), member.name))
        lines.append('  %s__fini(msg);' % message_typename)
        lines.append('  return false;')
        lines.append('}')
        if member.has_annotation('default'):
            lines.append('{')
            lines.append(
                '  bool success = %s__assign(&msg->%s, %s);' % (
                basetype_to_c(member.type), member.name,
                value_to_c(member.type, member.get_annotation_value('default')['value'])))
            lines.append('  if (!success) {')
            lines.append('    goto %s%s;' % (label_prefix, last_label_index))
            abort_lines[0:0] = [
                '  %s__fini(&msg->%s);' % (basetype_to_c(member.type), member.name),
                '%s%d:' % (label_prefix, last_label_index),
            ]
            last_label_index += 1
            lines.append('  }')
            lines.append('}')
    elif isinstance(member.type, BasicType):
        if member.has_annotation('default'):
            # set default value of primitive type
            lines.append('msg->%s = %s;' % (member.name, value_to_c(member.type, member.get_annotation_value('default')['value'])))

for line in lines:
    print('  ' + line)
}@
  return true;
@{
if abort_lines:
    # remove lines before the first label since they are unreachable
    while not abort_lines[0].startswith(label_prefix):
        abort_lines.pop(0)
    for line in abort_lines:
        print(line)
    print('  return false;')
}@
}

void
@(message_typename)__fini(@(message_typename) * msg)
{
  if (!msg) {
    return;
  }
@{
lines = []
for member in message.structure.members:
    lines.append('// ' + member.name)
    if isinstance(member.type, Array):
        if isinstance(member.type.value_type, (AbstractGenericString, NamespacedType)):
            lines.append('for (size_t i = 0; i < %d; ++i) {' % member.type.size)
            # initialize each array element
            lines.append('  %s__fini(&msg->%s[i]);' % (basetype_to_c(member.type.value_type), member.name))
            lines.append('}')
    elif isinstance(member.type, AbstractSequence):
        # finalize the dynamic array
        lines.append('%s__fini(&msg->%s);' % (idl_type_to_c(member.type), member.name))
    elif not isinstance(member.type, BasicType):
        # finalize non-array sub messages and strings
        lines.append('%s__fini(&msg->%s);' % (basetype_to_c(member.type), member.name))
for line in lines:
    print('  ' + line)
}@
}

bool
@(message_typename)__are_equal(const @(message_typename) * lhs, const @(message_typename) * rhs)
{
  if (!lhs || !rhs) {
    return false;
  }
@[for member in message.structure.members]@
  // @(member.name)
@[  if isinstance(member.type, Array)]@
  for (size_t i = 0; i < @(member.type.size); ++i) {
@[     if isinstance(member.type.value_type, (AbstractGenericString, NamespacedType))]@
    if (!@(basetype_to_c(member.type.value_type))__are_equal(
        &(lhs->@(member.name)[i]), &(rhs->@(member.name)[i])))
    {
      return false;
    }
@[     else]@
    if (lhs->@(member.name)[i] != rhs->@(member.name)[i]) {
      return false;
    }
@[     end if]@
  }
@[  elif isinstance(member.type, AbstractSequence)]@
  if (!@(idl_type_to_c(member.type))__are_equal(
      &(lhs->@(member.name)), &(rhs->@(member.name))))
  {
    return false;
  }
@[  elif isinstance(member.type, (AbstractGenericString, NamespacedType))]@
  if (!@(basetype_to_c(member.type))__are_equal(
      &(lhs->@(member.name)), &(rhs->@(member.name))))
  {
    return false;
  }
@[  else]@
  if (lhs->@(member.name) != rhs->@(member.name)) {
    return false;
  }
@[  end if]@
@[end for]@
  return true;
}

bool
@(message_typename)__copy(
  const @(message_typename) * input,
  @(message_typename) * output)
{
  if (!input || !output) {
    return false;
  }
@[for member in message.structure.members]@
  // @(member.name)
@[  if isinstance(member.type, Array)]@
  for (size_t i = 0; i < @(member.type.size); ++i) {
@[     if isinstance(member.type.value_type, (AbstractGenericString, NamespacedType))]@
    if (!@(basetype_to_c(member.type.value_type))__copy(
        &(input->@(member.name)[i]), &(output->@(member.name)[i])))
    {
      return false;
    }
@[     else]@
    output->@(member.name)[i] = input->@(member.name)[i];
@[     end if]@
  }
@[  elif isinstance(member.type, AbstractSequence)]@
  if (!@(idl_type_to_c(member.type))__copy(
      &(input->@(member.name)), &(output->@(member.name))))
  {
    return false;
  }
@[  elif isinstance(member.type, (AbstractGenericString, NamespacedType))]@
  if (!@(basetype_to_c(member.type))__copy(
      &(input->@(member.name)), &(output->@(member.name))))
  {
    return false;
  }
@[  else]@
  output->@(member.name) = input->@(member.name);
@[  end if]@
@[end for]@
  return true;
}

@(message_typename) *
@(message_typename)__create(void)
{
  rcutils_allocator_t allocator = rcutils_get_default_allocator();
  @(message_typename) * msg = (@(message_typename) *)allocator.allocate(sizeof(@(message_typename)), allocator.state);
  if (!msg) {
    return NULL;
  }
  memset(msg, 0, sizeof(@(message_typename)));
  bool success = @(message_typename)__init(msg);
  if (!success) {
    allocator.deallocate(msg, allocator.state);
    return NULL;
  }
  return msg;
}

void
@(message_typename)__destroy(@(message_typename) * msg)
{
  rcutils_allocator_t allocator = rcutils_get_default_allocator();
  if (msg) {
    @(message_typename)__fini(msg);
  }
  allocator.deallocate(msg, allocator.state);
}
