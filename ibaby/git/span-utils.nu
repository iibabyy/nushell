# Utilities for preserving span information across function boundaries
# This module provides a pattern for wrapping user-provided values with their
# metadata spans, enabling better error messages that point to the exact source.

# Create a spanned value from a user-provided parameter
# Captures the span metadata at the point of wrapping
export def make-spanned [
    value: any
]: nothing -> record<value: any, span: any> {
    { value: $value, span: (metadata $value | get span) }
}

# Create a spanned value for an optional parameter with a default
# If the value is null, uses the default with a null span
export def make-spanned-default [
    value: any
    default: any
]: nothing -> record<value: any, span: any> {
    if $value != null {
        { value: $value, span: (metadata $value | get span) }
    } else {
        { value: $default, span: null }
    }
}

# Create an error with optional span support
# Automatically uses --unspanned when span is null
#
# Examples:
#   make-error "File not found" $spanned_path
#   make-error "Invalid branch" $spanned_branch --label "not found" --hint "Check branch name"
export def make-error [
    msg: string
    spanned_value?: record<value: any, span: any>
    --label: string = "error"
    --hint: string
]: nothing -> nothing {
    let span = if $spanned_value != null { $spanned_value.span } else { null }

    if $span != null {
        let err = {
            msg: $msg,
            label: { text: $label, span: $span }
        }
        let full = if $hint != null { $err | insert help $hint } else { $err }
        error make $full
    } else {
        let err = { msg: $msg }
        let full = if $hint != null { $err | insert help $hint } else { $err }
        error make --unspanned $full
    }
}

# Create error from an error object (same structure as error make)
# Automatically uses --unspanned if label.span is missing or null
#
# Example:
#   make-error-with-span {
#       msg: "Path already exists"
#       label: { text: "path already exists", span: $spanned_path.span }
#       help: "Use --path to specify a different location"
#   }
export def make-error-with-span [
    error_object: any
]: nothing -> nothing {
    let has_span = (
        ($error_object.label? != null) and
        ($error_object.label.span? != null)
    )

    if $has_span {
        error make $error_object
    } else {
        error make --unspanned $error_object
    }
}
