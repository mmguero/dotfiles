#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# run imagededup (https://github.com/idealo/imagededup) on a directory/directories of images
# and write the results as JSON to STDOUT
#
# https://gist.github.com/mmguero/75ddc56f2961e5301bc14e46fbf75119

import argparse
import glob
import json
import logging
import numpy
import os
import sys
from itertools import chain
from imagededup.methods import CNN, PHash, DHash, WHash, AHash

###################################################################################################
script_name = os.path.basename(__file__)
script_path = os.path.dirname(os.path.realpath(__file__))


###################################################################################################
# special json encoder for numpy types
class NumpyEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, numpy.integer):
            return int(obj)
        elif isinstance(obj, numpy.floating):
            return float(obj)
        elif isinstance(obj, numpy.ndarray):
            return obj.tolist()
        return json.JSONEncoder.default(self, obj)


###################################################################################################
# main
def main():
    parser = argparse.ArgumentParser(
        description='\n'.join(['Use imagededup on a directory of images']),
        formatter_class=argparse.RawTextHelpFormatter,
        add_help=False,
        usage='{} <arguments>'.format(script_name),
    )
    parser.add_argument(
        '--verbose',
        '-v',
        action='count',
        default=1,
        help='Increase verbosity (e.g., -v, -vv, etc.)',
    )
    parser.add_argument(
        '--scores',
        dest='scores',
        action='store_true',
        help='Show scores',
    )
    parser.add_argument(
        '--no-scores',
        dest='scores',
        action='store_false',
        help='Don\'t show scores',
    )
    parser.set_defaults(scores=False)
    parser.add_argument(
        '-i',
        '--input',
        dest='inputDir',
        nargs='*',
        type=str,
        default=None,
        required=False,
        help="Input directory",
    )
    parser.add_argument(
        '-a',
        '--algorithm',
        required=False,
        dest='algorithm',
        metavar='<STR>',
        type=str,
        default='phash',
        help='Algorithm name',
    )
    parser.add_argument(
        '-m',
        '--max-split-size-mb',
        dest='maxSplitSizeMb',
        help="PYTORCH_CUDA_ALLOC_CONF max_split_size_mb value",
        metavar='<megabytes>',
        type=int,
        default=0,
        required=False,
    )
    try:
        parser.error = parser.exit
        args = parser.parse_args()
    except SystemExit:
        parser.print_help()
        exit(2)

    args.verbose = logging.ERROR - (10 * args.verbose) if args.verbose > 0 else 0
    logging.basicConfig(
        level=args.verbose, format='%(asctime)s %(levelname)s: %(message)s', datefmt='%Y-%m-%d %H:%M:%S'
    )
    logging.debug(os.path.join(script_path, script_name))
    logging.debug("Arguments: {}".format(sys.argv[1:]))
    logging.debug("Arguments: {}".format(args))
    if args.verbose > logging.DEBUG:
        sys.tracebacklimit = 0

    args.algorithm = args.algorithm.lower()
    if args.algorithm == 'cnn':
        hasher = CNN(verbose=args.verbose > logging.DEBUG)
    elif args.algorithm == 'phash':
        hasher = PHash(verbose=args.verbose > logging.DEBUG)
    elif args.algorithm == 'dhash':
        hasher = DHash(verbose=args.verbose > logging.DEBUG)
    elif args.algorithm == 'whash':
        hasher = WHash(verbose=args.verbose > logging.DEBUG)
    elif args.algorithm == 'ahash':
        hasher = AHash(verbose=args.verbose > logging.DEBUG)
    else:
        raise ValueError(f'Invalid algorithm {args.algorithm}')

    if int(args.maxSplitSizeMb) > 0:
        os.environ["PYTORCH_CUDA_ALLOC_CONF"] = f"max_split_size_mb:{args.maxSplitSizeMb}"

    dupes = hasher.find_duplicates(
        encoding_map={
            os.path.basename(fName): hasher.encode_image(image_file=fName)[0]
            for fName in list(chain([files for imgDir in args.inputDir for files in glob.glob(f"{imgDir}/*")]))
        },
        scores=args.scores,
    )

    print(json.dumps({k: v for k, v in dupes.items() if v}, indent=2, cls=NumpyEncoder))


###################################################################################################
if __name__ == '__main__':
    main()
