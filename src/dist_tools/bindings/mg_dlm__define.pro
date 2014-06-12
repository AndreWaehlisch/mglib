; docformat = 'rst'

;+
; Class representing a DLM made from a list of wrapper routines.
;
; :Examples:
;    This example creates a DLM to access a few internal IDL routines, but
;    this class could be used to access any C routines. The internal routines
;    are::
;
;       char *IDL_OutputFormatFunc(int type)
;       int IDL_OutputFormatLenFunc(int type)
;       int IDL_TypeSizeFunc(int type)
;       char *IDL_TypeNameFunc(int type)
;       void IDL_TTYReset(void)
;
;    To create a DLM of wrapper to access these routines, first create a
;    `MG_DLM` object with at least the `BASENAME` property::
;
;       f = mg_dlm(basename='format_example', $
;                  name='FORMAT_EXAMPLE', $
;                  description='Example of using dist_tools bindings', $
;                  version='1.0', source='dist_tools')
;
;    Next, add the prototypes of the routines requiring wrappers::
;
;       f->addRoutineFromPrototype, 'char *IDL_OutputFormatFunc(int type)'
;       f->addRoutineFromPrototype, 'int IDL_OutputFormatLenFunc(int type)'
;       f->addRoutineFromPrototype, 'int IDL_TypeSizeFunc(int type)'
;       f->addRoutineFromPrototype, 'char *IDL_TypeNameFunc(int type)'
;       f->addRoutineFromPrototype, 'void IDL_TTYReset(void)'
;
;    Alternatively, these prototype definitions could be placed in a file and
;    specified with the `addRoutinesFromHeaderFile` method.
;
;    Next, a wrapper to access the value of a `#define` constant is also
;    created::
;
;       f->addPoundDefineAccessor, 'IDL_TYP_UNDEF', type=3L
;
;    The `write` method writes the `.c` and `.dlm` files::
;
;       f->write
;
;    The `build` method invokes the compiler and linker to make the shared
;    object file containing the wrappers::
;
;       f->build, /show_all_output
;
;    The `register` method registers the DLM to be accessed in the current
;    IDL session::
;
;       f->register
;
;    The `MG_DLM` object is no longer needed::
;
;       obj_destroy, f
;
;    These commands are in a main-level program at the end of the file. To run
;    them do::
;
;       IDL> .run mg_dlm__define
;
;    Then you have access to the routines from IDL::
;
;       IDL> print, idl_outputformatfunc(5)
;       %#16.8g
;       IDL> print, idl_outputformatlenfunc(5)
;                 16
;       IDL> print, idl_typesizefunc(5)
;                  8
;       IDL> print, idl_typenamefunc(5)
;       DOUBLE
;       IDL> print, get_idl_typ_undef()
;                  0
;
; :Properties:
;    prefix
;      string to prefix routine names with
;    basename
;      basename (including possible path) for `.c` and `.dlm` files
;    name
;      name in DLM header
;    description
;      description in DLM header
;    version
;      version in DLM header
;    source
;      source in DLM header
;    build_date
;      date in DLM header
;    preamble
;      string/string array of code to be inserted after declarations, but before
;      argument checking
;-


;+
; Set properties.
;-
pro mg_dlm::setProperty, prefix=prefix, basename=basename, $
                         name=name, description=description, version=version, $
                         source=source, build_date=build_date, preamble=preamble
  compile_opt strictarr

  if (n_elements(prefix) gt 0L) then self.prefix = prefix
  if (n_elements(basename) gt 0L) then self.basename = basename
  if (n_elements(name) gt 0L) then self.name = name
  if (n_elements(description) gt 0L) then self.description = description
  if (n_elements(version) gt 0L) then self.version = version
  if (n_elements(source) gt 0L) then self.source = source
  if (n_elements(build_date) gt 0L) then self.build_date = build_date
  if (n_elements(preamble) gt 0L) then *self.preamble = preamble
end


;+
; Get properties.
;-
pro mg_dlm::getProperty, name=name, prefix=prefix
  compile_opt strictarr

  if (arg_present(name)) then name = self.name
  if (arg_present(prefix)) then prefix = self.prefix
end


;+
; Returns the `.c` file text as a string.
;
; :Private:
;
; :Returns:
;    string or `strarr(2)`
;
; :Keywords:
;   separate : in, optional, type=boolean
;     set to create separate output for bindings and routine declarations as
;     well as just have routine declarations for the DLM (no header)
;-
function mg_dlm::output_c, separate=separate
  compile_opt strictarr

  output = ''

  if (~keyword_set(separate)) then begin
    ; header
    output += string(systime(), format='(%"// Generated by dist_tools: %s")')

    output += mg_newline()

    ; system includes
    foreach i, self.systemIncludes do begin
      output += string(mg_newline(), i, format='(%"%s#include <%s>")')
    endforeach

    output += mg_newline()

    output += string(mg_newline(), format='(%"%s#include <stdio.h>")')
    output += string(mg_newline(), format='(%"%s#include <string.h>")')
    output += string(mg_newline(), format='(%"%s#ifdef strlcpy")')
    output += string(mg_newline(), format='(%"%s#undef strlcpy")')
    output += string(mg_newline(), format='(%"%s#endif")')
    output += string(mg_newline(), format='(%"%s#ifdef strlcat")')
    output += string(mg_newline(), format='(%"%s#undef strlcat")')
    output += string(mg_newline(), format='(%"%s#endif")')
    output += string(mg_newline(), format='(%"%s#include \"idl_export.h\"")')

    output += mg_newline()

    ; user includes
    foreach i, self.userIncludes do begin
      output += string(mg_newline(), i, format='(%"%s#include \"%s\"")')
    endforeach

    output += mg_newline()

    ; MG_GET_TYPE definitions
    idltypes_filename = filepath('mg_get_idltypes.c', root=mg_src_root())
    nlines = file_lines(idltypes_filename)
    lines = strarr(nlines)
    openr, lun, idltypes_filename, /get_lun
    readf, lun, lines
    free_lun, lun

    output += mg_strmerge(lines)

    output += mg_newline()
    output += mg_newline()
  endif

  ; routine bindings
  foreach r, self.routines do begin
    output += r->output(preamble=*self.preamble)
    output += mg_newline()
    output += mg_newline()
  endforeach

  if (~keyword_set(separate)) then begin
    output += mg_newline()
  endif

  ; IDL_Load
  if (~keyword_set(separate)) then begin
    output += string(mg_newline(), format='(%"int IDL_Load(void) {%s")')
    output += string(self.name, mg_newline(), mg_newline(), $
                     format='(%"  if (!(msg_block = IDL_MessageDefineBlock(\"%s\", IDL_CARRAY_ELTS(msg_arr), msg_arr))) { return IDL_FALSE; } %s%s")')
  endif

  func_output = ''
  if (self.nFunctions gt 0L) then begin
    if (~keyword_set(separate)) then begin
      output += string(mg_newline(), $
                       format='(%"  static IDL_SYSFUN_DEF2 function_addr[] = {%s")')
    endif

    foreach r, self.routines do begin
      r->getProperty, name=name, $
                      prefix=prefix, $
                      cprefix=cprefix, $
                      return_type=returnType, $
                      n_min_parameters=nMinParameters, $
                      n_max_parameters=nMaxParameters
      if (returnType eq 0L) then continue
      func_output += string(cprefix, $
                       name, $
                       strupcase(prefix + name), $
                       nMinParameters, $
                       nMaxParameters, $
                       mg_newline(), $
                       format='(%"    { %s_%s, \"%s\", %d, %d, 0, 0 },%s")')
    endforeach

    if (~keyword_set(separate)) then begin
      output += func_output
      output += string(mg_newline(), format='(%"  };%s")')
      output += mg_newline()
    endif
  endif

  proc_output = ''
  if (self.nProcedures gt 0L) then begin
    if (~keyword_set(separate)) then begin
      output += string(mg_newline(), $
                       format='(%"  static IDL_SYSFUN_DEF2 pro_addr[] = {%s")')
    endif

    foreach r, self.routines do begin
      r->getProperty, name=name, $
                      prefix=prefix, $
                      cprefix=cprefix, $
                      return_type=returnType, $
                      n_min_parameters=nMinParameters, $
                      n_max_parameters=nMaxParameters
      if (returnType ne 0L) then continue
      proc_output += string(cprefix, $
                       name, $
                       strupcase(prefix + name), $
                       nMinParameters, $
                       nMaxParameters, $
                       mg_newline(), $
                       format='(%"    { (IDL_SYSRTN_GENERIC) %s_%s, \"%s\", %d, %d, 0, 0 },%s")')
    endforeach

    if (~keyword_set(separate)) then begin
      output += proc_output
      output += string(mg_newline(), format='(%"  };%s")')
      output += mg_newline()
    endif
  endif

  func_reg = 'IDL_SysRtnAdd(function_addr, TRUE, IDL_CARRAY_ELTS(function_addr))'
  pro_reg = 'IDL_SysRtnAdd(pro_addr, FALSE, IDL_CARRAY_ELTS(pro_addr))'

  if (~keyword_set(separate)) then begin
    output += string(self.nFunctions gt 0L ? func_reg : '', $
                     (self.nFunctions gt 0L && self.nProcedures gt 0L) ? ' && ' : '', $
                     self.nProcedures gt 0L ? pro_reg : '', $
                     format='(%"  return %s%s%s;")')

    output += string(mg_newline(), format='(%"%s}")')
  endif

  return, keyword_set(separate) ? [output, func_output, proc_output]: output
end


;+
; Returns the `.dlm` file text as a string.
;
; :Private:
;
; :Returns:
;    string
;
; :Keywords:
;    no_header : in, optional, type=boolean
;       set to not output the header
;-
function mg_dlm::output_dlm, no_header=no_header
  compile_opt strictarr

  output = ''

  ; header
  if (~keyword_set(no_header)) then begin
    output += string(self.name, mg_newline(), format='(%"MODULE %s%s")')

    if (self.description ne '') then begin
      output += string(self.description, mg_newline(), $
                       format='(%"DESCRIPTION %s%s")')
    endif

    if (self.version ne '') then begin
      output += string(self.version, mg_newline(), format='(%"VERSION %s%s")')
    endif

    if (self.source ne '') then begin
      output += string(self.source, mg_newline(), format='(%"SOURCE %s%s")')
    endif

    output += string(self.build_date, mg_newline(), $
                     format='(%"BUILD_DATE %s%s")')

    output += mg_newline()
  endif

  ; routine definitions
  foreach r, self.routines do begin
    r->getProperty, name=name, $
                    prefix=prefix, $
                    return_type=returnType, $
                    n_min_parameters=nMinParameters, $
                    n_max_parameters=nMaxParameters
    format = string(strlen(name) > 30, format='(%"(\%\"\%-10s \%-%ds \%4d \%4d\%s\")")')
    output += string(returnType eq 0L ? 'PROCEDURE' : 'FUNCTION', $
                     strupcase(prefix + name), $
                     nMinParameters, $
                     nMaxParameters, $
                     mg_newline(), $
                     format=format)
  endforeach

  return, output
end


;+
; Writes the `.c` and `.dlm` files to the `BASENAME` location.
;
; :Keywords:
;   separate : in, optional, type=boolean
;     set to create separate output for bindings and routine declarations as
;     well as just have routine declarations for the DLM (no header)
;-
pro mg_dlm::write, separate=separate
  compile_opt strictarr

  output = [self->output_c(separate=separate), $
            self->output_dlm(no_header=keyword_set(separate))]

  ext = ['c', 'dlm']

  separate_ext = ['c', 'c', 'c', 'dlm']
  type = ['wrappers', 'regfunc', 'regproc', 'definitions']

  for i = 0L, n_elements(output) - 1L do begin
    if (keyword_set(separate)) then begin
      filename = string(self.basename, type[i], separate_ext[i], format='(%"%s_%s.%s")')
    endif else begin
      filename = string(self.basename, ext[i], format='(%"%s.%s")')
    endelse

    openw, lun, filename, /get_lun
    printf, lun, output[i]
    free_lun, lun
  endfor
end


;+
; Compiles and links the DLM.
;
; :Keywords:
;    _extra : in, optional, type=keywords
;       keywords to the `MG_MAKE_DLL` routine
;-
pro mg_dlm::build, _extra=e
  compile_opt strictarr

  if (n_elements(self.includeDirs) gt 0L) then begin
    includes = strjoin('-I"' + self.includeDirs->toArray() + '"', ' ')
  endif else includes = ''

  libs = ''

  if (n_elements(self.sharedLibFiles) gt 0L) then begin
    if (n_elements(self.libDirs) gt 0L) then begin
      libs += strjoin('-L' + self.libDirs->toArray(), ' ') + ' '
    endif

    if (n_elements(self.sharedLibFiles) gt 0L) then begin
      libs += strjoin('-l' + self.sharedLibFiles->toArray(), ' ') + ' '
    endif
  endif

  if (n_elements(self.staticLibFiles) gt 0L) then begin
    libs += strjoin(self.staticLibFiles->toArray(), ' ') + ' '
  endif

  mg_make_dll, self.basename, $
               extra_cflags=includes, extra_lflags=libs, $
               _extra=e
end


;+
; Register the DLM.
;-
pro mg_dlm::register
  compile_opt strictarr

  dlm_register, self.basename + '.dlm'
end


;+
; Load the DLM.
;-
pro mg_dlm::load
  compile_opt strictarr

  dlm_load, self.basename
end


;+
; Add an include file to the DLM.
;
; :Params:
;    name : in, required, type=string
;       name of the include file, including the .h
;
; :Keywords:
;    system : in, optional, type=boolean
;       set to indicate that the include is a system include file, i.e., that
;       there should be <>'s around the name instead of ""'s
;    header_directory : in, optional, type=string
;       filepath to include file, if not in a standard location
;-
pro mg_dlm::addInclude, name, system=system, $
                        header_directory=headerDir
  compile_opt strictarr

  if (keyword_set(system)) then begin
    if (total(self.systemIncludes eq name, /integer) eq 0L) then begin
      self.systemIncludes->add, name
    endif
  endif else begin
    found = 0B
    foreach n, name do begin
      if (total(self.userIncludes eq n, /integer) eq 0L) then begin
        self.userIncludes->add, n
      endif else found = 1B
    endforeach

    if (~found) then begin
      if (n_elements(headerDir) gt 0L) then self.includeDirs->add, expand_path(headerDir)
    endif
  endelse
end


;+
; Add a library to the link line.
;
; :Params:
;   libFiles : in, optional, type=string/strarr
;     library files
;
; :Keywords:
;   lib_directory : in, optional, type=string/strarr
;     directory of lib files, either a scalar string or an array the same
;     length as `lib_files`
;   static : in, optional, type=boolean
;     set to indicate libraries are to be statically linked
;-
pro mg_dlm::addLibrary, libFiles, lib_directory=libDirs, static=static
  compile_opt strictarr

  if (n_elements(libFiles) eq 0L) then return

  if (n_elements(libDirs) gt 0L) then begin
    _libDirs = libDirs
    for d = 0L, n_elements(libDirs) - 1L do begin
      _libDirs[d] = filepath(path_sep(), root=file_expand_path(libDirs[d]))
    endfor
  endif else _libDirs = ''

  if (keyword_set(static)) then begin
    self.staticLibFiles->add, _libDirs + libFiles, /extract
  endif else begin
    if (n_elements(libDirs) gt 0L) then self.libDirs->add, _libDirs, /extract
    self.sharedLibFiles->add, libFiles, /extract
  endelse
end


;+
; Adds a wrapper routine to the DLM.
;
; :Params:
;    routine : in, required, type=routine object
;       routine object to add to the DLM
;-
pro mg_dlm::addRoutine, routine
  compile_opt strictarr

  self.routines->add, routine
  routine->getProperty, return_type=returnType
  if (returnType eq 0L) then self.nProcedures++ else self.nFunctions++
end


;+
; Adds a wrapper routine defined by a prototype given by a string to the DLM.
;
; :Params:
;    proto : in, required, type=string
;       prototype of the routine to add to the DLM
;-
pro mg_dlm::addRoutineFromPrototype, proto
  compile_opt strictarr

  name = mg_parse_cprototype(proto, $
                             params=params, $
                             return_type=return_type, $
                             return_pointer=return_pointer)
  if (return_pointer) then return_type = 14L
  r = mg_routinebinding(name=name, $
                        prefix=self.prefix, $
                        return_type=return_type, $
                        return_pointer=return_pointer, $
                        prototype=proto)

  if (params[0] ne '') then begin
    for i = 0L, n_elements(params) - 1L do begin
      param_type = mg_parse_cdeclaration(params[i], $
                                         pointer=pointer, array=array, $
                                         device=device)
      if (size(param_type, /type) eq 7) then begin
        message, string(param_type, format='(%"unrecognized type: %s")'), /informational
      endif

      if (size(param_type, /type) eq 7 || param_type ne 0 || (param_type eq 0 && keyword_set(pointer))) then begin
        r->addParameter, type=param_type, $
                         pointer=pointer, array=array, device=device, $
                         prototype=params[i]
      endif
    endfor
  endif

  self->addRoutine, r
end


;+
; Adds wrapper routines from a header file.
;
; :Params:
;    filename : in, required, type=string
;       header filename
;-
pro mg_dlm::addRoutinesFromHeaderFile, filename
  compile_opt strictarr
  on_error, 2

  if (~file_test(filename)) then message, 'header file not found'

  nlines = file_lines(filename)
  prototypes = strarr(nlines)
  openr, lun, filename, /get_lun
  readf, lun, prototypes
  free_lun, lun

  foreach p, prototypes do begin
    ; if not an empty line or a comment then add a binding for the line
    if (strtrim(p, 2) ne '' && strmid(strtrim(p, 2), 0, 2) ne '//') then begin
      self->addRoutineFromPrototype, p
    endif
  endforeach
end


;+
; Adds wrapper routine to access the given `#define` value.
;
; :Params:
;    name : in, required, type=string
;       name of `#define`
;
; :Keywords:
;    type : in, required, type=long
;       `SIZE` type code for `#define` value
;-
pro mg_dlm::addPoundDefineAccessor, name, type=type
  compile_opt strictarr

  self->addRoutine, mg_routinePoundDefineAccessor(name=name, $
                                                  prefix=self.prefix, $
                                                  return_type=type)
end


;+
; Free resources.
;-
pro mg_dlm::cleanup
  compile_opt strictarr

  ptr_free, self.preamble
  obj_destroy, [self.routines, $
                self.systemIncludes, self.userIncludes, $
                self.includeDirs, self.libDirs, $
                self.staticLibFiles, self.staticLibFiles]
end


;+
; Create the DLM object.
;-
function mg_dlm::init, _extra=e
  compile_opt strictarr

  self.systemIncludes = list()
  self.userIncludes = list()
  self.routines = list()
  self.includeDirs = list()
  self.libDirs = list()
  self.sharedLibFiles = list()
  self.staticLibFiles = list()

  self.source = 'Generated by dist_tools'
  self.build_date = systime()

  self.preamble = ptr_new(/allocate_heap)

  self->setProperty, _extra=e

  return, 1
end


;+
; Define instance variables.
;
; :Fields:
;    prefix
;      string to add before each routine name, i.e., `MG_`
;    basename
;       basename (including possible path) for `.c` and `.dlm` files
;    name
;       name in DLM header
;    description
;       description in DLM header
;    version
;       version in DLM header
;    source
;       source in DLM header
;    build_date
;       date in DLM header
;    routines
;       `LIST` of routine objects
;    nFunctions
;       the number of functions added to the DLM
;    nProcedures
;       the number of procedures added to the DLM
;    systemIncludes
;       `LIST` of system include names
;    userIncludes
;       `LIST` of user include names
;    includeDirs
;       `LIST` of include directories
;    libDirs
;       `LIST` of lib directories
;    sharedLibFiles
;       `LIST` of shared lib files
;    staticLibFiles
;       `LIST` of static lib files
;-
pro mg_dlm__define
  compile_opt strictarr

  define = { mg_dlm, $
             prefix: '', $
             basename: '', $
             name: '', $
             description: '', $
             version: '', $
             source: '', $
             build_date: '', $
             preamble: ptr_new(), $
             routines: obj_new(), $
             nFunctions: 0L, $
             nProcedures: 0L, $
             systemIncludes: obj_new(), $
             userIncludes: obj_new(), $
             includeDirs: obj_new(), $
             libDirs: obj_new(), $
             sharedLibFiles: obj_new(), $
             staticLibFiles: obj_new() $
           }
end


; main-level example

; This example creates a DLM to access a few internal routines::
;
;   char *IDL_OutputFormatFunc(int type)
;   int IDL_OutputFormatLenFunc(int type)
;   int IDL_TypeSizeFunc(int type)
;   char *IDL_TypeNameFunc(int type)
;   void IDL_TTYReset(void)
;   IDL_LONG64 IDL_SysRtnNumEnabled(int is_function, int enabled)
;
; and a `#define` value::
;
;   #define IDL_TYP_UNDEF 0

f = mg_dlm(basename='format_example', $
           name='FORMAT_EXAMPLE', $
           description='Example of using dist_tools bindings', $
           version='1.0', source='dist_tools')

; these definitions could also be put into a file and added via the
; `addRoutinesFromHeaderFile` method instead
f->addRoutineFromPrototype, 'char *IDL_OutputFormatFunc(int type)'
f->addRoutineFromPrototype, 'int IDL_OutputFormatLenFunc(int type)'
f->addRoutineFromPrototype, 'int IDL_TypeSizeFunc(int type)'
f->addRoutineFromPrototype, 'char *IDL_TypeNameFunc(int type)'
f->addRoutineFromPrototype, 'void IDL_TTYReset()'
f->addRoutineFromPrototype, 'IDL_LONG64 IDL_SysRtnNumEnabled(int is_function, int enabled)'

f->addPoundDefineAccessor, 'IDL_TYP_UNDEF', type=3L

f->write
f->build, /show_all_output
f->register

obj_destroy, f

; normally, the routines in just compiled DLM can't be called until IDL returns
; to the command line, but EXECUTE, CALL_PROCEDURE, and CALL_FUNCTION can be
; used to get around this
; print, 'Calling a routine from the created DLM...'
; print, call_function('IDL_OutputFormatFunc', 5L), $
;        format='(%"Default double format: %s")'
;
; print, 'Accessing a #define from idl_export.h...'
; print, call_function('idl_typ_undef'), format='(%"#define IDL_TYP_UNDEF %d")'

end
