#!/bin/sh
#SBATCH --job-name=APC_2v8a_MD
#SBATCH --output=%j.o
#SBATCH --error=%j.e
##SBATCH --mail-type=END
##SBATCH --mail-user=hf2583@nyu.edu
#SBATCH --time=2-20:00:00
#SBATCH --nodes=1
#SBATCH --mem=100GB
#SBATCH -p argon
##SBATCH -w gpu7
#SBATCH -c 28
##SBATCH --gres=gpu:1
##SBATCH --constraint=g6230|2630v4

#load amber20z module automatically according to gpu model
module purge
export MODULEPATH=$MODULEPATH:/gpfsnyu/xspace/sungroup/modules
if [ "$SLURM_JOB_NODELIST" == "gpu7" ];then
# for 2080Ti, load avx512_cuda11.02 version
module load amber/20z
elif [ "$SLURM_JOB_NODELIST" == "gpu6" ];then
# for P100, load avx2_cuda11.02 version
module load amber/20z_avx2
elif [ "$SLURM_JOB_NODELIST" == "agpu8" ];then
# for 2080Ti, load avx512_cuda11.02 version
module load amber/20z
elif [ "$SLURM_JOB_NODELIST" == "argpu1" ];then
# for 3080Ti, load avx512_cuda11.02 version
module load amber/20gpu
else
# for K10, load avx2_cuda10.2 version
module load amber/20z_avx2_cuda10.2
fi

HQDIR=/gpfsnyu/home/hf2583/APC/2v8a
JOBDIR=/gpfsnyu/xspace/projects/IMT/MD/count/pre
SYSTEM=triad_
TOP=conf3_PI.prmtop
ID_NO=65
START=1
STOP=50
min_inputfile=min.in
heat_inputfile=heat.in
npt_eq_inputfile=npt_eq_fixed_solute.in

INIT_CONFIG=conf3_init.inpcrd
TRAJDIR=/gpfsnyu/xspace/projects/IMT/MD
tmp=/tmp/zl3289/amber1
min=yes
run_on_tmp=yes
heat=yes
eq_npt=yes
md_control=pmemd
NT=28
#mkdir $tmp
#cd $tmp
#cp $TRAJDIR/*relax*rst  $tmp
cd $TRAJDIR
# before we start with everything else, create a directory 
mkdir -p $TRAJDIR

if [ "$run_on_tmp" == "yes" ];then
        echo Calculation were performed on tmp directory on computation node
        echo NOTE: if job failure happen make sure you clean up any cookie crumble of your calculation may left on the computation node. 
        TEMPDIR=/tmp/${SLURM_JOB_USER}_${SLURM_JOB_ID}
        mkdir $TEMPDIR
        cd $TEMPDIR
else
        echo Calculation were performed on current node
        echo NOTE: Make sure that this calculation is not heavy one that read and write frequently otherwise this job might influence cluster performance.
fi
