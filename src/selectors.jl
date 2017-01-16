if libgtk_version >= v"3"     ### should work with v >= 2.4, but there is a bug for v < 3

    #https://developer.gnome.org/gtk2/stable/SelectorWidgets.html

    #GtkColorButton — A button to launch a color selection dialog
    #GtkColorSelectionDialog — A standard dialog box for selecting a color
    #GtkColorSelection — A widget used to select a color
    #GtkHSV — A 'color wheel' widget
    #GtkFileChooser — File chooser interface used by GtkFileChooserWidget and GtkFileChooserDialog
    #GtkFileChooserButton — A button to launch a file selection dialog
    #GtkFileChooserDialog — A file chooser dialog, suitable for "File/Open" or "File/Save" commands
    #GtkFileChooserWidget — File chooser widget that can be embedded in other widgets
    #GtkFileFilter — A filter for selecting a file subset
    #GtkFontButton — A button to launch a font selection dialog
    #GtkFontSelection — A widget for selecting fonts
    #GtkFontSelectionDialog — A dialog box for selecting fonts
    #GtkInputDialog — Configure devices for the XInput extension

    function push!(widget::GtkDialog, text::AbstractString, response::Integer)
        ccall((:gtk_dialog_add_button,libgtk), Ptr{GObject},
              (Ptr{GObject},Ptr{UInt8},Cint), widget, text, response)
        return widget
    end

    #if VERSION >= v"0.4-"
    #GtkFileChooserDialogLeaf(title::AbstractString, parent::GtkContainer, action::Integer, button_text_response::=>...; kwargs...) =
    #    GtkFileChooserDialogLeaf(title::AbstractString, parent, action, button_text_response; kwargs...)
    #end
    function GtkFileChooserDialogLeaf(title::AbstractString, parent::GtkContainer, action::Integer, button_text_response; kwargs...)
        w = GtkFileChooserDialogLeaf(ccall((:gtk_file_chooser_dialog_new,libgtk), Ptr{GObject},
                    (Ptr{UInt8},Ptr{GObject},Cint,Ptr{Void}),
                    title, parent, action, C_NULL); kwargs...)
        for (k,v) in button_text_response
            push!(w, k, v)
        end
        return w
    end

    run(widget::GtkDialog) = GLib.g_sigatom() do
        ccall((:gtk_dialog_run,libgtk), Cint, (Ptr{GObject},), widget)
    end

    const SingleComma = r"(?<!,),(?!,)"
    function GtkFileFilterLeaf(; name::Union{AbstractString,Void} = nothing, pattern::AbstractString = "", mimetype::AbstractString = "")
        filt = GtkFileFilterLeaf(ccall((:gtk_file_filter_new,libgtk), Ptr{GObject}, ()))
        if !isempty(pattern)
            name == nothing && (name = pattern)
            for p in split(pattern, SingleComma)
                p = replace(p, ",,", ",")   # escape sequence for , is ,,
                ccall((:gtk_file_filter_add_pattern,libgtk), Void, (Ptr{GObject}, Ptr{UInt8}), filt, p)
            end
        elseif !isempty(mimetype)
            name == nothing && (name = mimetype)
            for m in split(mimetype, SingleComma)
                m = replace(m, ",,", ",")
                ccall((:gtk_file_filter_add_mime_type,libgtk), Void, (Ptr{GObject}, Ptr{UInt8}), filt, m)
            end
        else
            ccall((:gtk_file_filter_add_pixbuf_formats,libgtk), Void, (Ptr{GObject},), filt)
        end
        ccall((:gtk_file_filter_set_name,libgtk), Void, (Ptr{GObject}, Ptr{UInt8}), filt, name === nothing || isempty(name) ? C_NULL : name)
        return filt
    end
    GtkFileFilterLeaf(pattern::AbstractString; name::Union{AbstractString,Void} = nothing) = GtkFileFilterLeaf(; name=name, pattern=pattern)

    GtkFileFilterLeaf(filter::GtkFileFilter) = filter

    function makefilters!(dlgp::GtkFileChooser, filters::Union{AbstractVector,Tuple})
        for f in filters
            ccall((:gtk_file_chooser_add_filter,libgtk), Void, (Ptr{GObject}, Ptr{GObject}), dlgp, GtkFileFilter(f))
        end
    end

    function open_dialog(title::AbstractString, parent = GtkNullContainer(), filters::Union{AbstractVector,Tuple} = String[]; kwargs...)
        dlg = GtkFileChooserDialog(title, parent, GConstants.GtkFileChooserAction.OPEN,
                                    (("_Cancel", GConstants.GtkResponseType.CANCEL),
                                     ("_Open",   GConstants.GtkResponseType.ACCEPT)); kwargs...)
        dlgp = GtkFileChooser(dlg)
        if !isempty(filters)
            makefilters!(dlgp, filters)
        end
        response = run(dlg)
        multiple = getproperty(dlg, :select_multiple, Bool)
        local selection
        if response == GConstants.GtkResponseType.ACCEPT
            if multiple
                filename_list = ccall((:gtk_file_chooser_get_filenames,libgtk), Ptr{_GSList{String}}, (Ptr{GObject},), dlgp)
                selection = String[f for f in GList(filename_list, #=transfer-full=#true)]
            else
                selection = bytestring(GAccessor.filename(dlgp))
            end
        else
            if multiple
                selection = String[]
            else
                selection = GLib.utf8("")
            end
        end
        destroy(dlg)
        return selection
    end

    function save_dialog(title::AbstractString, parent = GtkNullContainer(), filters::Union{AbstractVector,Tuple} = String[]; kwargs...)
        dlg = GtkFileChooserDialog(title, parent, GConstants.GtkFileChooserAction.SAVE,
                                    (("_Cancel", GConstants.GtkResponseType.CANCEL),
                                     ("_Save",   GConstants.GtkResponseType.ACCEPT)), kwargs...)
        dlgp = GtkFileChooser(dlg)
        if !isempty(filters)
            makefilters!(dlgp, filters)
        end
        ccall((:gtk_file_chooser_set_do_overwrite_confirmation,libgtk), Void, (Ptr{GObject}, Cint), dlg, true)
        response = run(dlg)
        if response == GConstants.GtkResponseType.ACCEPT
            selection = bytestring(GAccessor.filename(dlgp))
        else
            selection = GLib.utf8("")
        end
        destroy(dlg)
        return selection
    end
end
