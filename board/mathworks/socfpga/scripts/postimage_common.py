#!/usr/bin/env python
import sys, os, shutil, glob, imp, subprocess, time, shlex
import helper_func
from helper_func import *

####################################
# Helper functions
####################################
def _generate_a2_cfgFile(spl, cfgFile):

    # Pad the A2 image up to 1M
    # HPS will fail to boot with too small of a2 partition
    a2size = 1024*1024

    f = open(cfgFile, 'w')

    f.write("flash dummy {\n")
    f.write("    pebsize = 1\n")
    f.write("    lebsize = 1\n")
    f.write("    numpebs = %d\n" % a2size)
    f.write("}\n")

    f.write("image boot.a2 {\n")
    f.write("    flash{\n")
    f.write("    }\n")
    f.write('    flashtype = "dummy"\n')
    f.write("    partition spl {\n")
    f.write('        in-partition-table = "no"\n')
    f.write('        image = "%s" \n' % spl)   
    f.write("        size = %d\n" % a2size)
    f.write("    }\n")
    f.write("}\n")

    f.close()

def _generate_a2_img():
    imgFile = os.path.realpath("%s/boot.a2" % ENV['IMAGE_DIR'])
    rm(imgFile)
    print_msg("Generating a2 image: %s" % imgFile)

    cfgFile = "%s/boot.a2.cfg" % ENV['IMAGE_DIR']
    spl = "%s/u-boot-spl.bin.crc" % (ENV['IMAGE_DIR'])
    _generate_a2_cfgFile(spl, cfgFile)

    run_genimage(cfgFile, ENV['IMAGE_DIR'])
    return imgFile
   
##############
# Build the SD disk iamge
##############
def _make_sdimage(outputDir, image, catalog):
    buildDate = time.strftime("%F")
    tmpImg = "%s/sdcard.img" % ENV['IMAGE_DIR']
    imageFile = "%s/%s_sdcard_%s_%s.img" % (
        outputDir, catalog['boardName'], image['imageName'], buildDate)

    # Cleanup any previous images
    files = [tmpImg, imageFile, imageFile + ".gz"]
    for f in files:
        rm(f)

    # Generate the SD FAT partition config file
    gen_sd_fat_cfg()
    # Generate the A2 parition
    _generate_a2_img()

    print_msg("Generating target image: %s" % imageFile)
    run_genimage(catalog['defaultInfo']['genimage'], ENV['IMAGE_DIR'], None)

    # Rename the image file
    os.rename(tmpImg, imageFile)
        

    argStr = "gzip %s" % (imageFile)
    subprocess.call( argStr.split(), cwd=ENV['IMAGE_DIR'] )

####################################
# Public Functions
####################################
##############
# Set the default dtb
##############
def set_default_dtb(defaultApp):
    defaultDTB = "devicetree_%s.dtb" % (defaultApp['name'])
    shutil.copyfile("%s/%s" %(ENV['SD_DIR'], defaultDTB), "%s/socfpga.dtb" % (ENV['SD_DIR']))

##############
# Set the default bitstream
##############
def set_default_bitsream(defaultApp):
    shutil.copyfile(defaultApp['bit'], "%s/socfpga.rbf" % (ENV['SD_DIR']))
    
##############
# Build the SD card image
##############
def build_sdimage(outputDir, image, catalog):

    defaultApp = image['defaultApp']

    ##############
    # Move the kernel
    ##############
    shutil.copy("%s/zImage" % (ENV['IMAGE_DIR']), ENV['SD_DIR'] )

    ##############
    # Copy over the application specific rbfs
    ##############
    for app in image['appList']:
        if not app['bit'] is None:
            appBit = "%s/socfpga_%s.rbf" % (ENV['SD_DIR'], app['name'])
            shutil.copy(app['bit'], appBit)

    ##############
    # Copy over the u-boot script
    ##############
    scriptSrc = "%s/boot/u-boot-scr.txt" % (_PLATFORM_DIR) 
    if os.path.exists(scriptSrc):
        # Copy to image dir
        shutil.copy(scriptSrc, "%s/u-boot-scr.txt" % (ENV['IMAGE_DIR']) )    
        # Convert to uimage
        argStr = """%s/usr/bin/mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n "U-Boot Script" -d u-boot-scr.txt u-boot.scr""" % (ENV['HOST_DIR'])
        subprocess.call(shlex.split(argStr), cwd=ENV['IMAGE_DIR'])
        # move to sd card
        shutil.move("%s/u-boot.scr" % (ENV['IMAGE_DIR']), "%s/u-boot.scr" % (ENV['SD_DIR']))

    ##############
    # Copy over u-boot (SPL will load u-boot.img)
    ##############
    shutil.copy("%s/u-boot.img" % (ENV['IMAGE_DIR']), "%s/u-boot.img" % (ENV['SD_DIR']))
    
    ##############
    # Call the Altera Script
    ##############
    _make_sdimage(outputDir, image, catalog)

####################################
# Module Globals
####################################
_PLATFORM_SCRIPTS = os.path.dirname(os.path.realpath(__file__))
_PLATFORM_DIR = os.path.dirname(_PLATFORM_SCRIPTS)


