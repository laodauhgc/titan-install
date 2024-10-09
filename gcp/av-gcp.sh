#!/bin/bash
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
NC='\033[0m'
# Hàm sinh chuỗi ngẫu nhiên có độ dài 5 ký tự
generate_random_string() {
  local random_string=$(LC_ALL=C tr -dc 'a-z' < /dev/urandom | head -c 5 ; echo '')
  echo "${random_string}-$(LC_ALL=C tr -dc 'a-z' < /dev/urandom | head -c 5 ; echo '')"
}

# Hàm tạo project ID
generate_project_id() {
  local random_suffix=$(generate_random_string)
  echo "$random_suffix"
}

# Hàm tạo project name
generate_project_name() {
  random_numbers=$(generate_random_numbers)
  echo "My Project $random_numbers"
}

# Hàm sinh chuỗi ngẫu nhiên gồm 5 số
generate_random_numbers() {
  local random_numbers=$(shuf -i 0-99999 -n 1)
  printf "%05d" "$random_numbers"
}
generate_random_number() {
  echo $((1000 + RANDOM % 9000))
}
generate_valid_instance_name() {
  local random_number=$(generate_random_number)
  echo "laodau-${random_number}"
}

startup_script_url="https://raw.githubusercontent.com/laodauhgc/titan-install/main/gcp/av-docker.sh"
# List of regions and regions where virtual machines need to be created
zones=(
  "us-east4-a"
  "us-east1-b"
  "us-east5-a"
  "us-west2-a"
)
# Kiểm tra sự tồn tại của tổ chức
organization_id=$(gcloud organizations list --format="value(ID)" 2>/dev/null)
sleep 3
echo -e "${YELLOW}ID tổ chức của bạn là: $organization_id ${NC}"

# Lấy ID tài khoản thanh toán
billing_account_id=$(gcloud beta billing accounts list --format="value(name)" | head -n 1)
echo -e "${YELLOW} Billing_account_id của bạn là: $billing_account_id ${NC}"

# Hàm đảm bảo có đủ số lượng dự án
ensure_n_projects() {
  desired_projects=3
  if [ -n "$organization_id" ]; then
    current_projects=$(gcloud projects list --format="value(projectId)" --filter="parent.id=$organization_id" 2>/dev/null | wc -l)
  else
    current_projects=$(gcloud projects list --format="value(projectId)" 2>/dev/null | wc -l)
  fi

  echo -e "${RED} Tổng số dự án đang có là: $current_projects ${NC}"

  if [ "$current_projects" -lt "$desired_projects" ]; then
    projects_to_create=$((desired_projects - current_projects))
    echo -e "${RED} Chưa có đủ $desired_projects dự án, đang tiến hành tạo $projects_to_create dự án...${NC}"

    for ((i = 0; i < projects_to_create; i++)); do
      local project_id=$(generate_project_id)
      local project_name=$(generate_project_name)

      if [ -n "$organization_id" ]; then
        gcloud projects create "$project_id" --name="$project_name" --organization="$organization_id"
        sleep 3
      else
        gcloud projects create "$project_id" --name="$project_name"
        sleep 3
      fi
      sleep 8
      gcloud alpha billing projects link "$project_id" --billing-account="$billing_account_id"
      gcloud config set project "$project_id"
      echo -e "${ORANGE}Đã tạo dự án '$project_name' (ID: $project_id).${NC}"
      sleep 2
    done
  else
    echo -e "${ORANGE}Đã có đủ $desired_projects dự án.${NC}"
  fi
}

# Hàm tạo firewall rule cho một project
create_firewall_rule() {
    local project_id=$1
    gcloud compute --project="$project_id" firewall-rules create openmap --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=all --source-ranges=0.0.0.0/0
}

re_enable_compute_projects(){
    local projects=$(gcloud projects list --format="value(projectId)")
    echo -e "${ORANGE}projects list ${NC}: $projects"
    if [ -z "$projects" ]; then
        echo -e "${RED}The account has no projects.${NC}. ${ORANGE} Run lại script vừa chạy.  ${NC}"
        exit 1
    fi
    for project_ide in $projects; do
        echo -e "${BLUE} enable api & create firewall_rule  for project: $project_ide .....${NC}"
        gcloud services enable compute.googleapis.com --project "$project_ide"
        create_firewall_rule "$project_ide"
        echo -e "${BLUE}enabled compute.googleapis.com project: $project_ide ${NC}"
    done
}

# Hàm kiểm tra và chờ dịch vụ được enable
check_service_enablement() {
    local project_id="$1"
    local service_name="compute.googleapis.com"
    echo -e "${ORANGE}Đang kiểm tra trạng thái của dịch vụ $service_name trong dự án : $project_id...${NC}"

    while true; do
        service_status=$(gcloud services list --enabled --project "$project_id" --filter="NAME:$service_name" --format="value(NAME)")
        if [[ "$service_status" == "$service_name" ]]; then
            echo -e "${BLUE}Dịch vụ $service_name đã được enable trong dự án : $project_id.${NC}"
            break
        else
            echo -e "${RED}Dịch vụ $service_name chưa được enable trong dự án : $project_id. Đang đợi enable...${NC}"
        fi
    done
}

run_enable_project_apicomputer(){
   local projects=$(gcloud projects list --format="value(projectId)")
   for project_id in $projects; do
    check_service_enablement "$project_id"
   done
}

create_vms(){
    local projects=$(gcloud projects list --format="value(projectId)")
    for project_id in $projects; do
        echo -e "${ORANGE}processing create vm on project-id: $project_id ${NC}"
        gcloud config set project "$project_id"
        service_account_email=$(gcloud iam service-accounts list --project="$project_id" --format="value(email)" | head -n 1)
        if [ -z "$service_account_email" ]; then
            echo -e "${RED}No Service Account could be found in the project: $project_id ${NC}"
            continue
        fi
        for zone in "${zones[@]}"; do
            instance_name=$(generate_valid_instance_name)
            gcloud compute instances create "$instance_name" \
            --project="$project_id" \
            --zone="$zone" \
            --machine-type=t2d-standard-1 \
            --network-interface=network-tier=PREMIUM,nic-type=GVNIC,stack-type=IPV4_ONLY,subnet=default \
            --maintenance-policy=MIGRATE \
            --provisioning-model=STANDARD \
            --service-account="$service_account_email" \
            --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
            --create-disk=auto-delete=yes,boot=yes,device-name="$instance_name",image=projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20240607,mode=rw,size=80,type=projects/"$project_id"/zones/"$zone"/diskTypes/pd-balanced \
            --no-shielded-secure-boot \
            --shielded-vtpm \
            --shielded-integrity-monitoring \
            --labels=goog-ec-src=vm_add-gcloud \
            --metadata=startup-script-url="$startup_script_url" \
            --reservation-affinity=any
            if [ $? -eq 0 ]; then
                echo -e "${ORANGE}Created instance $instance_name in project $project_id at region $zone sucessfully.${NC}"
            else
                echo -e "${RED}Fail create instance $instance_name in project $project_id at region $zone.${NC}"
            fi
        done
    done

}

list_of_servers(){
    local projectsss=($(gcloud projects list --format="value(projectId)"))
    all_ips=()
    # Lặp qua từng dự án và lấy danh sách các địa chỉ IP công cộng
    for projects_id in "${projectsss[@]}"; do
        echo -e "${BLUE}Retrieving list of servers from project: $projects_id ${NC}"       
        # Đặt dự án hiện tại
        gcloud config set project "$projects_id"      
        # Lấy danh sách địa chỉ IP công cộng của các máy chủ trong dự án hiện tại
        ips=($(gcloud compute instances list --format="value(EXTERNAL_IP)" --project="$projects_id"))       
        # Thêm các địa chỉ IP vào mảng all_ips
        all_ips+=("${ips[@]}")
    done
    echo -e "${YELLOW}List of all public IP addresses: ${NC}"
    for ip in "${all_ips[@]}"; do
        echo "$ip"
    done

}

init_rm(){
    billing_accounts=$(gcloud beta billing accounts list --format="value(name)")
    # Vô hiệu hóa billing cho tất cả các project
    echo -e "${YELLOW} Bắt đầu vô hiệu hóa billing cho tất cả các project... ${NC}"
    for account in $billing_accounts; do
        for project in $(gcloud beta billing projects list --billing-account="$account" --format="value(projectId)"); do
            echo -e "${YELLOW}Vô hiệu hóa billing cho project: $project ${NC}"
            gcloud beta billing projects unlink "$project"
        done
    done
    echo -e "${YELLOW} Hoàn thành việc vô hiệu hóa billing.${NC}"
    # Xóa tất cả các project
    echo -e "Bắt đầu xóa tất cả các project..."
    for projectin in $(gcloud projects list --format="value(projectId)"); do
        echo -e "${RED}Đang xóa project: $projectin ${NC}"
        gcloud projects delete "$projectin" --quiet
    done
    echo -e "${YELLOW} Hoàn thành việc xóa tất cả các project.${NC}"
}

wait_for_projects_deleted() {
  local current_projects
  while true; do
    current_projects=$(gcloud projects list --format="value(projectId)" 2>/dev/null)
    if [ -z "$current_projects" ] || [ "$(echo "$current_projects" | wc -l)" -eq 0 ]; then
      echo -e "${BLUE}Tất cả các project đã bị xóa hoàn toàn.${NC}"
      break
    else
      echo -e "${RED}Vẫn còn $(echo "$current_projects" | wc -l) project đang tồn tại, chờ thêm...${NC}"
      sleep 7  # Chờ thêm trước khi kiểm tra lại
    fi
  done
}

wait_for_projects_created() {
  local desired_projects=2
  local current_projects=0
  
  while [ "$current_projects" -lt "$desired_projects" ]; do
    if [ -n "$organization_id" ]; then
      current_projects=$(gcloud projects list --format="value(projectId)" --filter="parent.id=$organization_id" 2>/dev/null | wc -l)
    else
      current_projects=$(gcloud projects list --format="value(projectId)" 2>/dev/null | wc -l)
    fi

    if [ "$current_projects" -ge "$desired_projects" ]; then
      echo -e "${BLUE}Đã có đủ số lượng dự án: $current_projects projects.${NC}"
      break
    else
      echo -e "${RED}Hiện tại có $current_projects dự án, đang chờ...${NC}"
      sleep 5  # Chờ 10 giây trước khi kiểm tra lại
    fi
  done
}

# Gọi hàm để đảm bảo có đủ số lượng dự án
# Hàm main: Chạy các hàm
main() {
    echo -e "${YELLOW}-------------------THIÊN BỒNG NGUYÊN SOÁI------------------${NC}"
    sleep 1
    echo -e "${YELLOW}                   *******DÁI BÉ TÍ HON*******                    ${NC}"
    echo -e "${RED}----------------Híp d â m chị ....-----------------${NC}"
    init_rm
    wait_for_projects_deleted
    ensure_n_projects
    wait_for_projects_created
    echo -e "${YELLOW}----------------Kiểm tra xong số lượng project.-----------------${NC}"
    re_enable_compute_projects
    run_enable_project_apicomputer
    echo -e "${YELLOW}----------------Tiến hành tạo VM......-------------${NC}"
    create_vms
    list_of_servers
    echo -e "${YELLOW} Done - Trên là danh sách VM${NC}"
}
main
