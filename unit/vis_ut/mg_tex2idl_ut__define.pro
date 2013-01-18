function mg_tex2idl_ut::test1
  compile_opt strictarr

  tex = 'a^{b^c}'
  idl = ''

  assert, mg_tex2idl(tex) eq idl, 'incorrect result for %s', tex

  return, 1
end


function mg_tex2idl_ut::test2
  compile_opt strictarr

  tex = 'a_{b_c}'
  idl = ''

  assert, mg_tex2idl(tex) eq idl, 'incorrect result for %s', tex

  return, 1
end



function mg_tex2idl_ut::test3
  compile_opt strictarr

  tex = 'a^5_b'
  idl = ''

  assert, mg_tex2idl(tex) eq idl, 'incorrect result for %s', tex

  return, 1
end


function mg_tex2idl_ut::test4
  compile_opt strictarr

  tex = 'R_{0^{-}_{\delta F}1}'
  idl = 'R!D0!S!E-!R!I!7d!XF!N!D1!N'

  assert, mg_tex2idl(tex) eq idl, 'incorrect result for %s', tex

  return, 1
end



pro mg_tex2idl_ut__define
  compile_opt strictarr

  define = { mg_tex2idl_ut, inherits MGutLibTestCase }
end
