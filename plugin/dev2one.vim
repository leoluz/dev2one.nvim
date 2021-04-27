command! -nargs=+ ListDir lua require'dev2one'.list(<q-args>)
command! -nargs=+ -complete=dir GoTest lua require'dev2one'.gotest(<f-args>)
command! GoTestNear lua require'dev2one'.gotest()
