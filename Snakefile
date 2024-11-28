from dotenv import load_dotenv
import os
import pandas as pd
from pathlib import Path
import re
load_dotenv()
dw_key = os.getenv('DW_AUTH_TOKEN')
# ---- SETUP ----
acs_year = 2022
cdc_year = 2023
cws_year = '15_24'
# year of release
proj_year = 2024
# equity_year = 2023


def r_with_args(script):
    cmd = f'Rscript {script} {acs_year} {cdc_year}'
    return cmd



def fill_yr(x, yr):
    # yr = re.sub(r'_', '-', str(yr))
    return x.format(year = yr)


datasets = pd.read_csv('_utils/manual/datasets.csv', index_col = 'project')
datasets['repo'] = datasets.apply(lambda x: fill_yr(x['repo'], x['year']), axis = 1)
datasets['tag'] = datasets.apply(lambda x: fill_yr(x['tag'], x['year']), axis = 1)
datasets['dataset'] = datasets.apply(lambda x: fill_yr(x['dataset'], x['year']), axis = 1)
datasets['dataset'] = datasets['dataset'].apply(lambda x: Path('input_data') / x)
datasets['headings'] = datasets['headings'].apply(lambda x: Path('_utils') / x)

envvars:
    'DW_AUTH_TOKEN'

# ---- RULES ----
# rule check_release:
#     params:

#     log:
#         'logs/.check_{proj}.json',
#     shell:
#         'bash ./scripts/check_relase.sh {}'
# use lookup function to get dataset from project name, then check for release and log?
        
rule download_data:
    output:
        datasets = datasets['dataset'],
        headings = datasets['headings'],
        flag = '.meta_downloaded.json',
    params:
        acs_year = acs_year,
        cdc_year = cdc_year,
        cws_year = cws_year,
    shell:
        '''
        bash ./scripts/00a_download_data.sh {params.acs_year} {params.cdc_year} {params.cws_year}
        '''

rule headings:
    input:
        # rules.download_data.output.acs_head,
        # rules.download_data.output.cdc_head,
        # rules.download_data.output.cws_head,
        headings = datasets['headings'],
    output:
        headings = 'to_viz/indicators.json',
    script:
        'scripts/00b_make_headings.R'

rule notes:
    input:
        sources = '_utils/manual/sources.txt',
        urls = '_utils/manual/urls.txt',
        methods = '_utils/manual/methods.txt',
    output:
        notes = 'to_viz/notes.json',
        xwalk = 'to_viz/town_cog_xwalk.json',
    params:
        acs_year = acs_year,
        cdc_year = cdc_year,
        cws_year = cws_year,
        proj_year = proj_year,
    script:
        'scripts/00c_make_notes.R'

rule combine_datasets:
    input:
        # acs = rules.download_data.output.acs,
        # cdc = rules.download_data.output.cdc,
        # cws = rules.download_data.output.cws,
        **datasets['dataset'].to_dict(),
        headings = rules.headings.output.headings,
        # cws_head = rules.download_data.output.cws_head,
        cws_head = datasets['headings']['cws'],
    params:
        acs_year = acs_year,
        cws_year = cws_year,
        cdc_year = cdc_year,
    output:
        comb = f'output_data/{acs_year}_acs_health_cws_comb.rds',
    script:
        'scripts/01_join_datasets.R'

rule distro:
    input:
        headings = rules.headings.output.headings,
        comb = rules.combine_datasets.output.comb,
    params:
        acs_year = acs_year,
    output:
        distro = f'to_distro/{acs_year}_town_acs_health_cws_distro.csv',
    script:
        'scripts/02_prep_distro.R'

rule viz_data:
    input:
        comb = rules.combine_datasets.output.comb,
    params:
        acs_year = acs_year,
    output:
        viz = f'to_viz/town_wide_{acs_year}.json',
    script:
        'scripts/03_prep_json_to_viz.R'


rule make_shapes:
    output:
        topo = 'to_viz/towns_topo.json',
    script:
        'scripts/04_make_shapefiles.R'


rule upload_shapes:
    input:
        topo = rules.make_shapes.output.topo,
    output:
        flag = '.shapes_uploaded.json'
    shell:
        'bash ./scripts/05_upload_shapes_release.sh {input}'


rule upload_viz_data:
    input:
        [rules.viz_data.output.viz,
         rules.headings.output.headings,
         rules.notes.output.notes,
         rules.notes.output.xwalk]
    output:
        flag = '.viz_uploaded.json',
    shell:
        '''
        bash ./scripts/07_upload_data_release.sh {input}
        '''


rule sync_to_dw:
    input:
        rules.distro.output,
    output:
        flag = '.dw_uploaded.json',
    params:
        key = os.environ['DW_AUTH_TOKEN'],
        year = acs_year,
        files = rules.distro.output,
    shell:
        '''
        bash ./scripts/06_sync_to_dw.sh {params.key} {params.year} {params.files}
        '''
    

# ---- MAIN TARGETS ----

rule readme:
    input:
        readme = 'README.qmd',
        snakefile = 'Snakefile',
    output:
        md = 'README.md',
        dag = 'dag.png',
    shell:
        'quarto render {input.readme}'

rule all_no_sync:
    default_target: True
    input:
        rules.readme.output.md,
        rules.viz_data.output,
        rules.distro.output,
        rules.upload_shapes.output.flag,
        rules.upload_viz_data.output.flag,
        # rules.sync_to_dw.output.flag,
        rules.download_data.output.flag,

rule all:
    input:
        rules.all_no_sync.input,
        rules.sync_to_dw.output.flag

# ---- CLEANUP ----
rule clean:
    shell:
        '''
        rm -f to_distro/*.csv \
            to_viz/*.json \
            to_viz/*.geojson \
            input_data/*.rds \
            input_data/*.csv \
            output_data/*.rds \
            _utils/*.txt \
            _utils/*.rds \
            {rules.download_data.output.flag} \
            {rules.upload_shapes.output.flag} \
            {rules.upload_viz_data.output.flag} \
            {rules.sync_to_dw.output.flag} \
            README.md
        '''