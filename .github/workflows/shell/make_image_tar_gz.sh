#!/bin/bash

set -ue

readonly WORKING_DIR_PATH=$(pwd)
readonly IMAGE_COMPRESS_DIR_NAME="image_compress"
readonly IMAGE_COMPRESS_DIR_PATH="${WORKING_DIR_PATH}/${IMAGE_COMPRESS_DIR_NAME}"
readonly IMAGES_DIR_NAME="images"
readonly IMAGES_DIR_PATH="${IMAGE_COMPRESS_DIR_PATH}/${IMAGES_DIR_NAME}"
readonly TAR_GZ_DIR_NAME="tar_gz"
readonly TAR_GZ_DIR_PATH="${IMAGE_COMPRESS_DIR_PATH}/${TAR_GZ_DIR_NAME}"
readonly IMAGE_TAR_GZ_LIST_NAME="image_tar_gz_list.txt"
readonly IMAGE_TAR_GZ_LIST_PATH="${TAR_GZ_DIR_PATH}/${IMAGE_TAR_GZ_LIST_NAME}"
rm -rf "${TAR_GZ_DIR_PATH}"
mkdir -p "${TAR_GZ_DIR_PATH}"
readonly TEMP_DIR_NAME="temp"
readonly TEMP_DIR_PATH="${WORKING_DIR_PATH}/${TEMP_DIR_NAME}"
rm -rf "${TEMP_DIR_PATH}"
mkdir -p "${TEMP_DIR_PATH}"
function cur_date(){
	date '+%Y/%m/%d %H:%M:%S'
}
function extract_common_dir_list(){
	local dir_list="${1}"
	echo "${dir_list}" \
	| awk \
		-v dir_list="${dir_list}" \
		 'BEGIN{
			dir_path_list_length = split(dir_list, dir_path_list, "\n")
		}{
			cur_path_regex = sprintf("^%s.*", $0)
			match_times = 0
			for(i=1; i <= dir_path_list_length; i++){
				path_el = dir_path_list[i]
				if(\
					!match(path_el, cur_path_regex)\
				) continue
				match_times++
				if(\
					match_times <= 1\
				) continue 
				print $0
				next
			}
	}' | awk -v IMAGES_DIR_PATH="${IMAGES_DIR_PATH}" '{
		if(!$0) next
		if($0 == IMAGES_DIR_PATH) next
		print $0
	}'
}
function extract_image_bundle_dir_path_list_con(){
	echo "${1}" \
	| awk \
		-v common_dir_list_con="${2}" '
		BEGIN{
			common_dir_list_length = split(common_dir_list_con, common_dir_list, "\n")
		}
		{
			for(i=1; i <= common_dir_list_length; i++){
				common_path_el = common_dir_list[i]
				common_path_el_regex = sprintf("^%s/", common_path_el)
				if(\
					!match($0, common_path_el_regex)\
				) continue
				print $0
			}
	}'
}
readonly all_image_bundle_dir_path_list_con=$(find "${IMAGES_DIR_PATH}" -type d | sort)
readonly common_dir_list_con=$(\
	extract_common_dir_list \
		"${all_image_bundle_dir_path_list_con}"\
)
readonly image_bundle_dir_path_list_con=$(\
	extract_image_bundle_dir_path_list_con \
		"${all_image_bundle_dir_path_list_con}" \
		"${common_dir_list_con}"\
)
for image_dir_path in ${image_bundle_dir_path_list_con}
do
	echo "## $(cur_date) ${image_dir_path}"
	image_dir_relative_path=$(\
		echo "${image_dir_path}" \
		| awk -v IMAGES_DIR_PATH="${IMAGES_DIR_PATH}" '{
			IMAGES_DIR_PATH_PREFIX_REGEX = sprintf(".*%s/", IMAGES_DIR_PATH)
			print gensub(IMAGES_DIR_PATH_PREFIX_REGEX, "", "1", $0)
		}' \
	)
	image_bundle_dir_path="${image_dir_relative_path//\//___}"
	file_name=$(\
		echo "${image_dir_path}" \
		| awk -v IMAGES_DIR_PATH="${IMAGES_DIR_PATH}" '{
			IMAGES_DIR_PATH_PREFIX_REGEX = sprintf(".*%s/", IMAGES_DIR_PATH)
			image_dir_relative_path = gensub(IMAGES_DIR_PATH_PREFIX_REGEX, "", "1", $0)
			printf "%s\n", gensub(/\//, "___", "g", image_dir_relative_path)
		}' \
	)
	temp_gz_working_dir_path="${TEMP_DIR_PATH}/${file_name}"
	temp_image_bundle_dir_path="${temp_gz_working_dir_path}/${image_dir_relative_path}"
	mkdir -p "${temp_image_bundle_dir_path}"
	cp -arvf \
		"${image_dir_path}"/* \
		"${temp_image_bundle_dir_path}"
	cd "${temp_gz_working_dir_path}"
	echo "### $(cur_date) tar ${file_name}.."
	tar \
		-cvpzf "${TAR_GZ_DIR_PATH}/${file_name}.tar.gz" \
		./ &

done
wait
rm -rf "${TEMP_DIR_PATH}"
cd "${WORKING_DIR_PATH}"
image_bundle_prefix="${IMAGE_COMPRESS_DIR_NAME}/${TAR_GZ_DIR_NAME}"
find "${TAR_GZ_DIR_PATH}" -mindepth 1 -maxdepth 1 -type f \
| awk -v WORKING_DIR_PATH="${WORKING_DIR_PATH}" '{
	cmd = sprintf("du -b --max-depth=0 \x22%s\x22 | cut -f1 ", $0)
	cmd | getline tar_gz_size
	close(cmd)
	WORKING_DIR_PATH_PREFIX_REGEX = sprintf("^%s/", WORKING_DIR_PATH)
	relativeDirPath = gensub(WORKING_DIR_PATH_PREFIX_REGEX, "", "1", $0)
   	printf "relativeDirPath=%s,size=%s\n", relativeDirPath, tar_gz_size
}' > "${IMAGE_TAR_GZ_LIST_PATH}"


