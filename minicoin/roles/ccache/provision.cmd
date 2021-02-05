call /minicoin/util/parse-opts.cmd %USERPROFILE% %@

choco install -y --no-progress ccache
for %%p in (!PARAMS[@]!) do (
    ccache --set-config=%%p=!PARAM_%%p!
)
