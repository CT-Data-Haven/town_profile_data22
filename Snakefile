from dotenv import load_dotenv
import os
load_dotenv()
dw_key = os.getenv('DW_AUTH_TOKEN')
# ---- SETUP ----
acs_year = 2022
cdc_year = 2023
equity_year = 2023


def r_with_args(script):
    cmd = f'Rscript {script} {acs_year} {cdc_year}'
    return cmd

envvars:
    'DW_AUTH_TOKEN'

# ---- RULES ----
rule download_data:
    output:
        acs = f'input_data/acs_town_basic_profile_{acs_year}.rds',
        cdc = f'input_data/cdc_health_all_lvls_nhood_{cdc_year}.rds',
        civic = 'input_data/cws_1521_civic_by_loc.csv',
        health = 'input_data/cws_1521_health_race.csv',
        walk = 'input_data/cws_1521_walkability_race.csv',
        acs_head = '_utils/acs_indicator_headings.txt',
        cdc_head = '_utils/cdc_indicators.txt',
        cws_head = '_utils/cws_indicator_headings.txt',
        flag = '.meta_downloaded.json',
    params:
        acs_year = acs_year,
        cdc_year = cdc_year,
        equity_year = equity_year,
    shell:
        '''
        bash ./scripts/00a_download_data.sh {params.acs_year} {params.cdc_year} {params.equity_year}
        '''

rule headings:
    input:
        rules.download_data.output.acs_head,
        rules.download_data.output.cdc_head,
        rules.download_data.output.cws_head,
    output:
        headings = 'to_viz/indicators.json',
    script:
        'scripts/00b_make_headings.R'

rule notes:
    input:
        sources = '_utils/manual/sources.txt',
        urls = '_utils/manual/urls.txt',
    output:
        notes = 'to_viz/notes.json',
        xwalk = 'to_viz/town_cog_xwalk.json',
    script:
        'scripts/00c_make_notes.R'

rule combine_datasets:
    input:
        acs = rules.download_data.output.acs,
        cdc = rules.download_data.output.cdc,
        civic = rules.download_data.output.civic,
        health = rules.download_data.output.health,
        walk = rules.download_data.output.walk,
        headings = rules.headings.output.headings,
    params:
        acs_year = acs_year,
        cdc_year = cdc_year,
    output:
        comb = f'output_data/{acs_year}_acs_health_cws_comb.rds',
    script:
        'scripts/01_join_acs_health.R'

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
        data = rules.viz_data.output.viz,
        headings = rules.headings.output.headings,
        notes = rules.notes.output.notes,
    output:
        flag = '.viz_uploaded.json',
    shell:
        'bash ./scripts/07_upload_data_release.sh {input.data} {input.headings} {input.notes}'


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

rule all:
    default_target: True
    input:
        rules.readme.output.md,
        rules.viz_data.output,
        rules.distro.output,
        rules.upload_shapes.output.flag,
        rules.upload_viz_data.output.flag,
        # rules.sync_to_dw.output.flag,
        rules.download_data.output.flag,

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