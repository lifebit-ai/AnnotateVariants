# Rare Disease Pipeline
## Author: Phillip Richmond (prichmond@bcchr.ca | phillip.a.richmond@gmail.com)

## About: This is a shell script built for WGS/WES Trio sequencing data. 
### The general flow is to modify the variables at the top of the script, and then run the script (sh RareDiseasePipeline.sh)
### to produce a series of shell scripts which can be submitted to the scheduler.
### Future iterations of this master script may include nextflow/snakemake

## NOTES
### for directory variables, I make both a variable and it's _VAR equivalent, and use the _VAR for the sed commands below
### I had to do this because of sed and the damn "/", but I may also want to use the directories themselves for things like copying files
### Or checking that files exist

# Case/Sample Specific Variables (Change these)
EMAIL=prichmond@bcchr.ca
# either WGS or WES
SEQ_TYPE=WGS

# FAMILY INFO
FAMILY_ID=EPGEN055
RAW_DIR=/mnt/scratch/Precision/EPGEN/RAW/$FAMILY_ID/
RAW_DIR_VAR="\/mnt\/scratch\/Precision\/EPGEN\/RAW\/$FAMILY_ID\/"
WORKING_DIR=/mnt/scratch/Precision/EPGEN/PROCESS/${FAMILY_ID}/
WORKING_DIR_VAR="\/mnt\/scratch\/Precision\/EPGEN\/PROCESS\/${FAMILY_ID}\/"
PED=$WORKING_DIR/${FAMILY_ID}.ped

# PROBAND INFO
PROBAND_SEX=male
PROBAND_ID=EPGEN055-01
PROBAND_FASTQR1=EPGEN055-01_1.fastq.gz
PROBAND_FASTQR2=EPGEN055-01_2.fastq.gz

#MOTHER_INFO
MOTHER_ID=EPGEN055-02
MOTHER_FASTQR1=EPGEN055-02_1.fastq.gz
MOTHER_FASTQR2=EPGEN055-02_2.fastq.gz

#FATHER_INFO
FATHER_ID=EPGEN055-03
FATHER_FASTQR1=EPGEN055-03_1.fastq.gz
FATHER_FASTQR2=EPGEN055-03_2.fastq.gz

# HPO Ids (for exomiser, keep in this format):
# "['HP:#######','HP:#######',...,'HP:#######']
EXOMISER_HPO_VECTOR="['HP:0001250','HP:0001249','HP:0010851','HP:0002360','HP:0001263']"

# Cutoffs for filtering on rarity from GNOMAD
# Allele Frequency Cutoff (0.001 = 0.1%), Homozygous Alt Cutoff ( Fewer than <int> in gnomAD)
AF_CUTOFF=0.001
HOM_ALT_CUTOFF=15


# Tool/database Variables (Do not change these)
GENOME_BUILD=GRCh38
FASTA_DIR=/mnt/common/DATABASES/REFERENCES/GRCh38/GENOME/1000G/
FASTA_DIR_VAR="\/mnt\/common\/DATABASES\/REFERENCES\/GRCh38\/GENOME\/1000G\/"
FASTA_FILE=GRCh38_full_analysis_set_plus_decoy_hla.fa
ANNOTATE_VARIANTS_DIR=/mnt/common/WASSERMAN_SOFTWARE/AnnotateVariants/
ANNOTATE_VARIANTS_DIR_VAR='\/mnt\/common\/WASSERMAN_SOFTWARE\/AnnotateVariants\/'
MTOOLBOX_DIR='\/mnt\/common\/WASSERMAN_SOFTWARE\/MToolBox\/'
LOFSCORESFILE_VAR='\/mnt\/common\/DATABASES\/GENERIC\/VEP\/LoFtool_scores.txt'
SPLICEAISNV_VAR='\/mnt\/common\/DATABASES\/REFERENCES\/GRCh38\/SPLICEAI\/spliceai_scores.masked.snv.hg38.vcf.gz'
SPLICEAIINDEL_VAR='\/mnt\/common\/DATABASES\/REFERENCES\/GRCh38\/SPLICEAI\/spliceai_scores.masked.indel.hg38.vcf.gz'
CACHEDIR_VAR='\/mnt\/common\/DATABASES\/REFERENCES\/GRCh38\/VEP\/'
PLUGINSDIR_VAR='\/mnt\/common\/DATABASES\/REFERENCES\/GRCh38\/VEP\/PLUGINS\/'
MAXENTSCANDIR_VAR='\/mnt\/common\/WASSERMAN_SOFTWARE\/VEP\/fordownload\/'
SLIVAR_VAR='\/mnt\/common\/Precision\/Slivar\/'
GFF_VAR='\/mnt\/common\/DATABASES\/REFERENCES\/GRCh38\/GENOME\/Homo_sapiens.GRCh38.100.chr.gff3.gz'
EXOMISER_JAR=exomiser-cli-12.1.0.jar
EXOMISER_DIR='\/mnt\/common\/WASSERMAN_SOFTWARE\/Exomiser\/exomiser-cli-12.1.0\/'
MELT_DIR_VAR='\/mnt\/common\/WASSERMAN_SOFTWARE\/MELTv2.2.0\/'
PEDMAKER=$ANNOTATE_VARIANTS_DIR/PipelineScripts/MakePED.py
EHDN_DIR_VAR='\/mnt\/common\/Precision\/ExpansionHunterDenovo\/ExpansionHunterDenovo-v0.9.0-linux_x86_64\/'
ANNOVAR_DIR_VAR='\/mnt\/common\/WASSERMAN_SOFTWARE\/annovar\/'
EHDN_BACKGROUND_DIR_VAR='\/mnt\/common\/DATABASES\/REFERENCES\/GRCh38\/ExpansionHunterDeNovo\/EHdn_v0.9.0_1000G_hg38\/'


# For EHdn
MINICONDA_DIR_VAR='\/mnt\/common\/Precision\/Miniconda2\/'
# For MELT
MINICONDA3_DIR_VAR='\/mnt\/common\/Precision\/Miniconda3\/'

# SCRIPT TEMPLATE LOCATION
TEMPLATE_DIR=$ANNOTATE_VARIANTS_DIR/TemplateScripts/

# Set up working directory
mkdir -p $WORKING_DIR

#################################################################################

##########
# Step 1 #
##########

# Create a PED File with the info above
## NOTE: You will hav eto change this according to your case for affected parents, duos, etc.
## Make a PED File
## Works like this:
## python MakePED.py --proband TIDEX1000_BWAmem,male,affected --father TIDEX1002_BWAmem,male,unaffected --mother TIDEX1001_BWAmem,female,unaffected --family T272 -O T272.ped
python $PEDMAKER \
        --proband ${PROBAND_ID}_$GENOME_BUILD,$PROBAND_SEX,affected \
        --father ${FATHER_ID}_$GENOME_BUILD,male,unaffected \
        --mother ${MOTHER_ID}_$GENOME_BUILD,female,unaffected \
        -F $FAMILY_ID \
        -O $PED

              
##########   
# Step 2 #  
##########   

# Map, Convert, Mark Duplicates: BWA mem, Samtools, Picard
STEP2_TEMPLATE=RunMappingPipeline_WithDupRemoval_Template.sh
## Input: Fastq.R1.gz, Fastq.R2.gz, indexed fasta
## Output: dupremoved.sorted.bam for each sample

## Step 2 Proband
### Copy to scripts directory
cp $TEMPLATE_DIR/$STEP2_TEMPLATE ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}

### Make changes with sed to replace values, starting with Change ID
sed -i "s/sample/$PROBAND_ID/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}
sed -i "s/raw_dir/$RAW_DIR_VAR/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}
sed -i "s/annotate_variants_dir/$ANNOTATE_VARIANTS_DIR_VAR/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}
sed -i "s/fasta_dir/$FASTA_DIR_VAR/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}
sed -i "s/fasta_file/$FASTA_FILE/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}
sed -i "s/genome_build/$GENOME_BUILD/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}
sed -i "s/fastqr1/$PROBAND_FASTQR1/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}
sed -i "s/fastqr2/$PROBAND_FASTQR2/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP2_TEMPLATE}

## Step 2 Mother
### Copy to scripts directory
cp $TEMPLATE_DIR/$STEP2_TEMPLATE ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}

### Make changes with sed to replace values, starting with Change ID
sed -i "s/sample/$MOTHER_ID/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}
sed -i "s/raw_dir/$RAW_DIR_VAR/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}
sed -i "s/annotate_variants_dir/$ANNOTATE_VARIANTS_DIR_VAR/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}
sed -i "s/fasta_dir/$FASTA_DIR_VAR/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}
sed -i "s/fasta_file/$FASTA_FILE/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}
sed -i "s/genome_build/$GENOME_BUILD/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}
sed -i "s/fastqr1/$MOTHER_FASTQR1/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}
sed -i "s/fastqr2/$MOTHER_FASTQR2/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP2_TEMPLATE}

## Step 2 Father
### Copy to scripts directory
cp $TEMPLATE_DIR/$STEP2_TEMPLATE ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}

### Make changes with sed to replace values, starting with Change ID
sed -i "s/sample/$FATHER_ID/g" ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}
sed -i "s/raw_dir/$RAW_DIR_VAR/g" ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}
sed -i "s/annotate_variants_dir/$ANNOTATE_VARIANTS_DIR_VAR/g" ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}
sed -i "s/fasta_dir/$FASTA_DIR_VAR/g" ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}
sed -i "s/fasta_file/$FASTA_FILE/g" ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}
sed -i "s/genome_build/$GENOME_BUILD/g" ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}
sed -i "s/fastqr1/$FATHER_FASTQR1/g" ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}
sed -i "s/fastqr2/$FATHER_FASTQR2/g" ${WORKING_DIR}/${FATHER_ID}_${STEP2_TEMPLATE}



##########
# Step 3 #
##########

# DeepTrio --> GLNexus: Joint Genotype to produce SNV/indel
STEP3_TEMPLATE=RunDeepTrio_Template.sh
## Copy template to working directory
cp $TEMPLATE_DIR/$STEP3_TEMPLATE ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}

## Input: Dupremoved.sorted.bam for proband, mother, father
## Output: Merged.vcf.gz (joint called for trio)

## Edit the template
sed -i "s/annotate_variants_dir/$ANNOTATE_VARIANTS_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/raw_dir/$RAW_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/fasta_dir/$FASTA_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/fasta_file/$FASTA_FILE/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/genome_build/$GENOME_BUILD/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/proband_id/$PROBAND_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/mother_id/$MOTHER_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/father_id/$FATHER_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/family_id/$FAMILY_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}
sed -i "s/seq_type/$SEQ_TYPE/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP3_TEMPLATE}



##########
# Step 4 #
##########

# Mitochondrial analysis: MToolBox 
STEP4_TEMPLATE=RunMToolBox_Template.sh

## Input: Fastq.R1.gz, Fastq.R2.gz
## Output: MToolBox prioritized variants

## Proband
### Copy the template
cp ${TEMPLATE_DIR}/$STEP4_TEMPLATE ${WORKING_DIR}/${PROBAND_ID}_${STEP4_TEMPLATE}

### Edit the template
sed -i "s/annotate_variants_dir/$ANNOTATE_VARIANTS_DIR_VAR/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP4_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP4_TEMPLATE}
sed -i "s/raw_dir/$RAW_DIR_VAR/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP4_TEMPLATE}
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP4_TEMPLATE}
sed -i "s/sample_id/$PROBAND_ID/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP4_TEMPLATE}
sed -i "s/mtoolbox_dir/$MTOOLBOX_DIR/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP4_TEMPLATE}
sed -i "s/family_id/$FAMILY_ID/g" ${WORKING_DIR}/${PROBAND_ID}_${STEP4_TEMPLATE}

## Mother
### Copy the template
cp ${TEMPLATE_DIR}/$STEP4_TEMPLATE ${WORKING_DIR}/${MOTHER_ID}_${STEP4_TEMPLATE}

### Edit the template
sed -i "s/annotate_variants_dir/$ANNOTATE_VARIANTS_DIR_VAR/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP4_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP4_TEMPLATE}
sed -i "s/raw_dir/$RAW_DIR_VAR/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP4_TEMPLATE}
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP4_TEMPLATE}
sed -i "s/sample_id/$MOTHER_ID/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP4_TEMPLATE}
sed -i "s/mtoolbox_dir/$MTOOLBOX_DIR/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP4_TEMPLATE}
sed -i "s/family_id/$FAMILY_ID/g" ${WORKING_DIR}/${MOTHER_ID}_${STEP4_TEMPLATE}


##########
# Step 5 #
##########
# Annotate SNV/Indel & Create GEMINI Database: BCFTools, Slivar, VCFAnno, VCF2DB, GEMINI
STEP5_TEMPLATE=AnnotationPipelineSNVindel_Template.sh

## Input: Merged.vcf.gz
## Output: Gemini.db

## Copy the template
cp ${TEMPLATE_DIR}/$STEP5_TEMPLATE ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}

## Edit the template
sed -i "s/annotate_variants_dir/$ANNOTATE_VARIANTS_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/family_id/$FAMILY_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/fasta_dir/$FASTA_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/fasta_file/$FASTA_FILE/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/lofscoresfile/$LOFSCORESFILE_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/spliceai_snv/$SPLICEAISNV_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/spliceai_indel/$SPLICEAIINDEL_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/cache_dir/$CACHEDIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/plugins_dir/$PLUGINSDIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/maxentscan_dir/$MAXENTSCANDIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/slivar_dir/$SLIVAR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/gff_file/$GFF_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/af_cutoff/$AF_CUTOFF/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}
sed -i "s/hom_alt_cutoff/$HOM_ALT_CUTOFF/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP5_TEMPLATE}


##########
# Step 6 #
##########
# Query GEMINI Database to produce CVL: GEMINI, AnnotateVariants (for formatting python scripts)
STEP6_TEMPLATE=GeminiQueries_GRCh38_Template.sh

## Input: Gemini.db
## Output: CVL.tsv

## Copy the template
cp ${TEMPLATE_DIR}/$STEP6_TEMPLATE ${WORKING_DIR}/${FAMILY_ID}_${STEP6_TEMPLATE}

## Edit the template
sed -i "s/annotate_variants_dir/$ANNOTATE_VARIANTS_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP6_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP6_TEMPLATE}
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP6_TEMPLATE}
sed -i "s/family_id/$FAMILY_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP6_TEMPLATE}


##########
# Step 7 #
##########

# Automated Variant Prioritization: Exomiser
STEP7_YML_TEMPLATE=Exomiser_Template.yml
STEP7_RUN_TEMPLATE=RunExomiser_Template.sh

## Input: Merged.vcf.gz
## Output: Exomiser HTML + CSVs

## Copy the templates
cp ${TEMPLATE_DIR}/$STEP7_YML_TEMPLATE ${WORKING_DIR}/${FAMILY_ID}_${STEP7_YML_TEMPLATE}
cp ${TEMPLATE_DIR}/$STEP7_RUN_TEMPLATE ${WORKING_DIR}/${FAMILY_ID}_${STEP7_RUN_TEMPLATE}

## Edit the run template
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP7_RUN_TEMPLATE}
sed -i "s/exomiser_jar/$EXOMISER_JAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP7_RUN_TEMPLATE}
sed -i "s/exomiser_dir/$EXOMISER_DIR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP7_RUN_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP7_RUN_TEMPLATE}
sed -i "s/family_id/$FAMILY_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP7_RUN_TEMPLATE}

## Edit the YML config template
## Here I'll make a couple more variables based on what we defined above, because I'm not sure how Exomiser YML handles variables
## So instead, I'll just create them here! Hooray Bash!
## NOTE: This exomiser run is hard configured for hg38
EXOMISER_OUTPUT_PREFIX=${FAMILY_ID}_Exomiser
EXOMISER_PROBAND_ID=${PROBAND_ID}_${GENOME_BUILD}
EXOMISER_VCF=${FAMILY_ID}.merged.vcf.gz
EXOMISER_PED=${FAMILY_ID}.ped
sed -i "s/hpo_vector/$EXOMISER_HPO_VECTOR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP7_YML_TEMPLATE}
sed -i "s/in_merged_vcfgz/$EXOMISER_VCF/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP7_YML_TEMPLATE}
sed -i "s/in_ped/$EXOMISER_PED/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP7_YML_TEMPLATE}
sed -i "s/proband_id/$EXOMISER_PROBAND_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP7_YML_TEMPLATE}
sed -i "s/output_prefix/$EXOMISER_OUTPUT_PREFIX/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP7_YML_TEMPLATE}


##########
# Step 8 #
##########

# Call Mobile Element Insertions (MEIs) + Anno: MELT + AnnotSV
STEP8_TEMPLATE=RunMELT_Template.sh

## Input: Dupremoved.sorted.bam
## Output: ALU.vcf, LINE.vcf, SINE.vcf

## Copy the template
cp ${TEMPLATE_DIR}/$STEP8_TEMPLATE ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}

## Edit the template
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}
sed -i "s/miniconda3_dir/$MINICONDA3_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}
sed -i "s/genome_build/$GENOME_BUILD/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}
sed -i "s/fasta_dir/$FASTA_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}
sed -i "s/fasta_file/$FASTA_FILE/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}
sed -i "s/family_id/$FAMILY_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}
sed -i "s/melt_dir/$MELT_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}
sed -i "s/proband_id/$PROBAND_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}
sed -i "s/father_id/$FATHER_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}
sed -i "s/mother_id/$MOTHER_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP8_TEMPLATE}


###########  Everything Below is Currently in Dev (2021-04-22)

##########
# Step 9 #
##########

# ExpansionHunter Denovo (REs) + Anno
STEP9_TEMPLATE=RunExpansionHunterDenovo_Template.sh

## Input: dupremoved.sorted.bam
## Output: EHdn annotated tsv

## Copy the template
cp ${TEMPLATE_DIR}/$STEP9_TEMPLATE ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}

## Edit the template
sed -i "s/email_address/$EMAIL/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/miniconda_dir/$MINICONDA_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/genome_build/$GENOME_BUILD/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/fasta_dir/$FASTA_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/fasta_file/$FASTA_FILE/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/family_id/$FAMILY_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/proband_id/$PROBAND_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/mother_id/$MOTHER_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/father_id/$FATHER_ID/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/working_dir/$WORKING_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/annovar_dir/$ANNOVAR_DIR_VAR/g" ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/ehdn_dir_var/$EHDN_DIR_VAR/g"  ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}
sed -i "s/ehdn_background_dir/$EHDN_BACKGROUND_DIR_VAR/g"  ${WORKING_DIR}/${FAMILY_ID}_${STEP9_TEMPLATE}

exit
# Step 10 #
# ExpansionHunter 3





# Step 11 #
# Parliament2 (SVs) + Anno




# Experimental stuff?
# Scripts still in development # ...




