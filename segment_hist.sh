#!/bin/bash

# Usage message
usage () {
    cat <<-_EOF_
        $PROGNAME: usage: $PROGNAME [test] [ARGS]
        $1
        For more information check the help page: $PROGNAME [-h | --help]
_EOF_
    return
}

# Print the help page
pleh () {
    less <<- _EOF_
    $PROGNAME
    ===============================================================================

    SYNOPSIS
    --------
    $PROGNAME [ARGS] 
    $PROGNAME test [ARGS]

    
    DESCRIPTION
    -----------
    $PROGNAME implements a semi-automatic pipeline to segment tissue slices from 
    the background in high resolution whole-slde histopathological images and 
    extracts patches of tissue segments from the full resolution image. 

    Whole slide histological images are very large in terms of size, making it 
    difficult for computational pipelines to process them as single units, thus, 
    they have to be divided into patches. Moreover, a significant portion of each 
    image is background, which should be excluded from downstream analyses. 
    
    In order to efficiently segment tissue content from each image, $PROGNAME 
    utilizes a Canny edge detector and a graph-based segmentation method. A lower 
    resolution version of the image, extracted from the whole slide image file,
    is segmented. The background is defined as the segments that can be found at the
    borders or corners of the image (for more details check -b and -c arguments 
    documentation). Finally, patches are extracted from the full size image ,while
    the corresponding patches are checked in the segmented image. Patches with a 
    "tissue content" greater than a threshold value (-t) are selected.

    Moreover, $PROGNAME can function in test mode. This could assist the user in 
    setting the appropriate parameters for the pipeline. In test mode, $PROGNAME 
    will output the segmented version of the input image with scales indicating 
    the number of rows and columns. In that image the background should be separate 
    from the tissue pieces for the pipeline to work properly. 
    Proper use: $PROGNAME test [-s | -m  | -k | -l | -h] -i INPUT_FILE

    
    ARGUMENTS
    ---------
    -s
    --sigma_F
        Parameter required by the segmentation algorithm. 
        Used to smooth the input image before segmenting it.
        Default value is 0.5.

    -m
    --min_F
        Parameter required by the segmentation algorithm. 
        Minimum segment size enforced by post-processing.
        Larger images require higher values.
        Default value is 100000.

    -k
    --k_F
        Parameter required by the segmentation algorithm.
        Value for the threshold function. The threshold function controls the 
        degree to which the difference between two segments must be greater than
        their internal differences in order for them not to be merged. Lower values
        result in finer segmentation. Larger images require higher values.
        Default value is 20000.

    -l
    --level
        Integer indicating the level of the whole slide image file which will be 
        used to produce the segmentation. It should be greater than 0, beacause 
        level 0 is the full resolution image. Default value is 1, the second 
        largest version of the image.

    -p
    --save_patches
        Save the produced patches of the full resolution image. By default, 
        $PROGNAME will not save them.

    -t
    --content_threshold
        Threshold parameter indicating the proportion of a patch content that 
        should not be covered by background in order to be selected. It should
        range between 0 and 1. Default value is 0.5.

    -d
    --patch_size
        Integer indicating the size of the produced patches. A value of D
        will produce patches of size D x D. Default value is 512. 

    -n
    --number_of_lines
        Integer indicating the number of lines from the borders or the corners of
        the segmented image that the algorithm should take into account to define
        background. Default value is 100.

    -b
    --borders
        A four digit string. Each digit represents a border of the image in the 
        following order: left, bottom, right, top. If the digit is equal to 1 and
        not 0, then the corresponding border will be taken into account to define
        background. For instane, with -b 1010 the algorithm will look at the left
        and right borders of the segmented image, in a window of width defined by
        the -n argument, and every segment identified will be set as background. 
        If this argument is not equal to 0000, then -c should be 0000. 
        Default value is 1111.

    -c
    --corners
        A four digit string. Each digit represents a corner of the image in the 
        following order: top_left, bottom_left, bottom_right, top_right. If the 
        digit is equal to 1 and not 0, then the corresponding corner will be taken
        into account to define background. For instane, with -c 0101 the algorithm
        will look at the bottom_left and top_right corners of the segmented image,
        in a square window of size given by the -n argument, and every segment
        identified will be set as background. If this argument is not equal to 0000,
        then -b should be 0000. Default value is 0000.

    -x
    --save_tilecrossed_image
        Produce a thumbnail of the original image, in which the selected patches
        are marked with a blue X. By default, $PROGNAME will not do this.

    -f
    --save_mask
        Keep the produced segmented image. By default, $PROGNAME will delete it.

    -e
    --save_edges
        Keep the image produced by the Canny edge detector. 
        By default, $PROGNAME will delete it.

    -i
    --image_file
        The whole slide image input file.

    -h
    --help
        Output help page.
    
    Note: Arguments should be separated from their values with a space!!!
          See examples.

    
    EXAMPLES
    --------
    
    Keep segmented image, save patches, produce a thumbnail with marked the
    selected patches, use a content threshold of 0.1 for patch selection.
    
    $PROGNAME -pfxt 0.1 -i INPUT_FILE
    
    $PROGNAME -p -f -x -t 0.1 -i INPUT_FILE

    Do not save patches, produce thumbnail, use different than the default values
    for k and m parameters.
    
    $PROGNAME -xk 10000 -m 1000 -i INPUT_FILE

    Do not save patches, produce thumbnail, use a content threshold of 0.1 for
    patch selection, for background identification use bottom_left and top_right
    corners.
    
    $PROGNAME -xt 0.1 -b 0000 -c 0101 -i INPUT_FILE

    Function in test mode, use different than the default values for k and m 
    parameters.
    
    $PROGNAME test -k 1000 -m 1000 -i INPUT_FILE

    
    REFERENCES
    ----------
    Felzenszwalb, P.F., & Huttenlocher, D.P. (2004). Efficient Graph-Based Image 
    Segmentation. International Journal of Computer Vision, 59, 167-181.

_EOF_
    return
}

# Settings
PROGNAME=`basename "$0"`
cd "$(dirname "$0")"

# Check if the Felzenswalb algorithm is compiled
if [ ! -f src/Felzenszwalb_algorithm/segment ]; then
    echo "Compiling Felzenswalb algorithm..."
    cd src/Felzenszwalb_algorithm
    make
    echo "Done"
fi

#read command line arguments
if [[ $1 == 'test' ]]; then
    test_image='True'
    shift
    while [[ -n $1 ]]; do
        case $1 in
            -s | --sigma_F)                   shift
                                              sigma=$1
                                              ;;
            -m | --min_F)                     shift
                                              min=$1
                                              ;;
            -k | --k_F)                       shift
                                              k=$1
                                              ;;
            -l | --level)                     shift
                                              level=$1
                                              ;;
            -i | --image_file)                shift
                                              svs=$1
                                              ;;
            -h | --help)                      pleh
                                              exit
                                              ;;
            *)                                usage 'Invalid argument!' >&2
                                              exit 1
                                              ;;
        esac
        shift
    done
else
    while [[ -n $1 ]]; do
        if [[ ${#1} -gt 2 && ${1:0:2} != '--' ]]; then
            #echo "in the if: $1"
            for (( i=1; i<${#1}; ++i )); do
                arg=${1:$i:1}
                case $arg in
                    s) shift
                       sigma=$1
                       ;;
                    m) shift
                       min=$1
                       ;;
                    k) shift
                       k=$1
                       ;;
                    l) shift
                       level=$1
                       ;;
                    p) save_patches='True'
                       ;;
                    t) shift
                       thres=$1
                       ;;
                    d) shift
                       patch_size=$1
                       ;;
                    n) shift
                       lines=$1
                       ;;
                    b) shift
                       borders=$1
                       ;;
                    c) shift
                       corners=$1
                       ;;
                    x) save_tilecrossed='True'
                       ;;
                    i) shift
                       svs=$1
                       ;;
                    h) pleh
                       exit
                       ;;
                    f) save_mask='True'
                       ;;
                    e) save_edges='True'
                       ;;
                    *) usage 'Invalid argument!' >&2
                       exit 1
                       ;;
                esac
                unset arg
            done
            shift
        else
            case $1 in
                -s | --sigma_F)                   shift
                                                  sigma=$1
                                                  ;;
                -m | --min_F)                     shift
                                                  min=$1
                                                  ;;
                -k | --k_F)                       shift
                                                  k=$1
                                                  ;;
                -l | --level)                     shift
                                                  level=$1
                                                  ;;
                -p | --save_patches)              save_patches='True'
                                                  ;;
                -t | --content_threshold)         shift
                                                  thres=$1
                                                  ;;
                -d | --patch_size)                shift
                                                  patch_size=$1
                                                  ;;
                -n | --number_of_lines)           shift
                                                  lines=$1
                                                  ;;
                -b | --borders)                   shift
                                                  borders="$1"
                                                  ;;
                -c | --corners)                   shift
                                                  corners="$1"
                                                  ;;
                -x | --save_tilecrossed_image)    save_tilecrossed='True'
                                                  ;;
                -h | --help)                      pleh
                                                  exit
                                                  ;;
                -f | --save_mask)                 save_mask='True'
                                                  ;;
                -e | --save_edges)                save_edges='True'
                                                  ;;
                -i | --image_file)                shift
                                                  svs=$1
                                                  ;;
                *)                                usage 'Invalid argument!' >&2
                                                  exit 1
                                                  ;;
            esac
            shift
        fi
    done
fi

#check for the image input
[[ -n $svs ]] || { usage 'Invalid or absent input!' >&2; exit 1; }

#set default values for parameters
sigma=${sigma:-0.5}
min=${min:-100000}
k=${k:-20000}
level=${level:-1}
save_patches=${save_patches:-'False'}
thres=${thres:-0.5}
patch_size=${patch_size:-512}
lines=${lines:-100}
borders=${borders:-'1111'}
corners=${corners:-'0000'}
save_tilecrossed=${save_tilecrossed:-'False'}
save_mask=${save_mask:-'False'}
save_edges=${save_edges:-'False'}

# Argument checking
# Borders
[[ $borders == '0000' ]] && [[ $corners == '0000' ]] && { usage 'Invalid borders and corners parameters!' >&2; exit 1; }
[[ $borders != '0000' ]] && [[ $corners != '0000' ]] && { usage 'Invalid borders and corners parameters!' >&2; exit 1; }

# Image level
[[ $level =~ ^[[:digit:]]+$ ]] || { usage 'Level parameter has to be integer!' >&2; exit 1; }

# Content threshold for the image
(( $(bc <<< "$thres >= 0 && $thres <= 1") )) || { usage 'Invalid content threshold parameter!' >&2; exit 1; }

# Patch size
[[ $patch_size =~ ^[[:digit:]]+$ ]] || { usage 'patch_size parameter has to be integer!' >&2; exit 1; }

# Lines to check on the borders
[[ $lines =~ ^[[:digit:]]+$ ]] || { usage 'number_of_lines parameter has to be integer!' >&2; exit 1; }

#create a temporary folder
dt=$(date '+%d%m%y%H%M%S')
image=${svs%.*}
image=${image##*/}
echo $image
temp="${image}_${dt}"
mkdir $temp

#produce edge image
echo 'Producing edge image...'
python "src/produce_edges.py" $svs "$temp/edges_$image.jpg" $level
# convert "$temp/edges_$image.jpg" "$temp/$image.ppm"
# echo OK

# #run Felzenszwalb algorithm
# echo 'Segmenting image...'
# src/Felzenszwalb_algorithm/segment $sigma $k $min "$temp/$image.ppm" "$temp/segmented_$image.ppm"
# echo OK

# #delete image.ppm
# rm $temp/$image.ppm

# #test mode
# [[ $test_image == 'True' ]] && { echo "Producing test image..."; python src/test_image.py $temp $image; mv "$temp/test_$image.png" $cwd; rm -r $temp; echo "ALL DONE!"; exit; }


# #produce and select tiles
# echo 'Extracting tiles...'
# python src/patch_selector.py $temp $image $thres $patch_size $lines $borders $corners $save_tilecrossed $save_patches $svs

# #delete mask and edge images
# [[ $save_mask == 'False' ]] && rm "$temp/segmented_$image.ppm"
# [[ $save_edges == 'False' ]] && rm "$temp/edges_$image.jpg"

# #turn the results visible
# mv "$temp" "${image}_${PROGNAME}_output"
# echo 'ALL DONE!'