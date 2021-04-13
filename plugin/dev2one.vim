command! -nargs=+ -bar ListDir lua require'dev2one'.list(<q-args>)
command! -bar GoTest lua require'dev2one'.gotest()
