-- names that will be exported from this module
return {
  -- user facing options
  maps = true,          -- if the default mappings should be defined
  git_colors = false,   -- if the highlighting from the git should be used
  -- follow the end of the file when it changes (like tail -f or less +F)
  follow = false,
  follow_interval = 500, -- intervall to check the underlying file in ms
}
