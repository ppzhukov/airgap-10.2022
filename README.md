# airgap-10.2022
Материалы к вебинару установки SUSE Rancher Airgap
## Системные требования
Для установки RKE/RKE2/K3S и Rancher в инфраструктуре с воздушным зазором нам потредуется:
1. Выделенная машина с доступом в интернет, котора скачает все необходимые для установки данные.
2. Сервер Registry в нутри безопасного контура на котором разместяться данные требуемые для развертывание инфраструктуры.
3. Jump Host с помощью которого мы будем управлять развертываемыми серверами.
4. Хосты на которые мы будем производить установку.

рис.1 Архитектура решения
```mermaid
flowchart TB
style id1 fill:#90EBCD
style id2 fill:#30BA78
style id3 fill:#30BA78
style id4 fill:#30BA78
style d10 fill:#EEEEEE

  id1([Машина с доступом в интернет])
  direction LR
  id1 -.Ручной перенос данных.-> id2  
  subgraph d10 ["Сеть без доступа в интернет"]
    id2(["Registry/Jump Host"])
    id2 --> |Развертывание| d30
    subgraph d30 [" "]
      id3([SUSE Rancher Nodes])
      id4([RKE2 Nodes])
    end
  end
```
В тестовом варианте мы можем совместить ряд ролей (Например Registry и Jump Host, роли серверов Kubernetes)
В нашем вебинаре мы будем ипользовать следующий стек продуктов и роли.
1. Сервер с доступом в интенет на базе SUSE Linux Enterprise Server.
2. Данный пример использует в качестве среды виртуализации VMware vSphere, но Вы можете использовать любую другую, создав необходимый шаблон виртуальной машины и подключив нужные модули в Rancher, если требуется его интеграция.
3. Template для узлов в VMware vSphere (который мы создадим чуть позже), а также преднастроенные узлы и сетевой сегмент для развертывание.  
4. Jump Host, с помощью которого будет производиться настройка узлов сети и на котором будет размещен Docker Registry
5. В Вашей обособленной сети должна быть доступна служба DNS, если ее нет, Вы можете для тестов воспользоваться [sslip.io](https://github.com/cunnie/sslip.io) для реализации простого DNS доступа.
6. В Вашей обособленной сети должен быть настроен DHCP. Вы можете использовать только статические адресса для Ваших стендов, но тема интеграции VMware vSphere с SUSE Rancher для использования только статическоих адресов и автоматического развертывания кластеров RKE выходит за рамки этого вебинара.
7. Три узела для развертывания Rancher.
8. Три узла для развертывания управляемого кластера (будут созданны Racnher, донастроенны cloud-init).

### Аппаратные требования
- 1x Front Server
  4 vCPU
  16 GiB RAM
  1 x HDD 300GB 

- 1x Jump Host
  4 vCPU
  16 GiB RAM
  1 x HDD 300GB (для registry)
  Поскольку мы совместили роли, нам понадобиться больше места: хранить копию данных образов для загрузки, копию данных образов в Docker, копию данных образов в Registry.

- 3x dedicate server for Rancher
  4 vCPU
  16 GiB RAM
  1 x HDD - > 100 GB

- 3x RKE2 Node - role: ETCD, Controls Plane, Worker
  16 vCPU
  64 GiB RAM
  1 x HDD - > 320 GB
  Поскольку мы совместили роли, нам понадобиться больше ресурсов для запуска реальной нагрузки.

### Используемые версии
- SUSE RKE2 v1.24.6+rke2r1 (Версия Kubernetes 1.24 для SUSE Rancher v2.6.8
- SUSE Rancher v2.6.8
- SUSE SLES 15 SP4
- Helm v3.9.4 (Поддерживаемые версии Kubernetes 1.24.x - 1.21.x)
- Сert Manager v1.7.1
- SUSE Longhorn v1.2

## Установка и настройка сервера с доступом в интернет
На данном сервере Вам потребуется Linux с установленным Docker. Я рекомендую установить SUSE Linux Enterprise Server в базовой конфигурации (Это может быть вариант Minimal для которого можно использовать следующую [инструкцию](front_server-install_script.md), но потребуется действующая подписка (ключ активации) для онлайн установки ряда пакетов).
Вы можете установить все обновления SUSE Linux Enterprise Server, для этого Вам потребуется ключ активации, возможно также использование триального ключа.
Вы также можете использовать OpenSUSE заменив ряд команд.
И так, если Вы решили использовать SUSE Linux Enterprise Server, при установке добавте следующие модули:
  - Containers Module
  - Server Applications Module
1. Установить и запустить Docker
  - Если у Вас есть клоюч активации и система активирована выполните следующую команду:
```bash
sudo SUSEConnect -p sle-module-containers/15.4/x86_64
```
Или
  - Если Вы установили SLES с DVD без подключения источников обновления и дополнительных модулей, то оставьте DVD в приводе (Важно, Вам нужен full ISO):
```bash
sudo yast2 add-on
```
  Выберите Add => DVD => Подключите DVD образ => Отметьте "Containers Module" => Next => Accept => OK => Finish => OK
 
Для установки docker выполните:
```bash
sudo zypper in -y docker
sudo usermod -aG docker sles
sudo usermod -aG docker root
sudo systemctl enable --now docker
sudo chown root:docker /var/run/docker.sock
```
2. Установка CLI helm
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
sudo ./get_helm.sh -v v3.9.4
```
3. Найдите и скачайте файлы требуемой версии Rancher
Перейдите страницу с данными [releases](https://github.com/rancher/rancher/releases) и найдите релиз v2.x.x версии которой хотите установить и нажмите Assets. Примечание. Не используйте выпуски с пометкой *rc* или *Pre-release*, так как они нестабильны и не для производственной среды.
Скачайте из секции Assets следующие файлы (они тербуются для установки в окружение с воздушным зазором):
- __rancher-images.txt__  Этот файл содержит список образов требуемых для установки Rancher, развертывания коастера и использования инструментов (tools) Rancher.
- __rancher-save-images.sh__	Этот скрипт скачает (pulls) все образы из rancher-images.txt с Docker Hub и сохранит их как rancher-images.tar.gz
- __rancher-load-images.sh__	Этот скрипт загрузит (loads) образы из rancher-images.tar.gz и выгрузит (pushes) в частное (private) registry.

В данном вебинаре мы используем:
```bash
wget https://github.com/rancher/rancher/releases/download/v2.6.8/rancher-images.txt
wget https://github.com/rancher/rancher/releases/download/v2.6.8/rancher-save-images.sh
wget https://github.com/rancher/rancher/releases/download/v2.6.8/rancher-load-images.sh
```


4. Получите список образов cert-manager (менеджер сертификатов)
При установке Kubernetes если Вы выберете использование самоподписные сертификаты (default self-signed TLS certificates) Вам требуется добавить список образов в файл __rancher-images.txt__.
  1. Получите latest cert-manager helm chart и выгрузите из шаблона информацию об образах:
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm fetch jetstack/cert-manager --version v1.7.1
helm template ./cert-manager-v1.7.1.tgz | awk '$1 ~ /image:/ {print $2}' | sed s/\"//g >> ./rancher-images.txt
``` 
  2. Отсортируйте список и оставьте только уникальные записи:
```bash
sort -u rancher-images.txt -o rancher-images.txt
```
5. Получите список образов RKE2
  1. Перейдите на страницу [releases page](https://github.com/rancher/rke2/releases), Найдите RKE2 release который планируете установить и нажмите Assets.
В секции Assets скачайте следующий файл со списком образов требуемых для установки RKE2 в инфраструктуре с воздушным зазором:
 __rke2-images-all.linux-amd64.txt__

  2. Добавте образы RKE2 к файлу __rancher-images.txt__:
```bash
wget https://github.com/rancher/rke2/releases/download/v1.24.6%2Brke2r1/rke2-images-all.linux-amd64.txt
cat rke2-images-all.linux-amd64.txt >> ./rancher-images.txt
```
  3. Отсортируйте и оставьте только уникальные записи:
```bash
sort -u rancher-images.txt -o rancher-images.txt
```
6. Сохраните образы на Вашу рабочую станцию
  1. сделайте __rancher-save-images.sh__ исполняемым:
```bash
chmod +x rancher-save-images.sh
```
  2. Запустите __rancher-save-images.sh__ используя список образов __rancher-images.txt__ image для создания tarball:
```bash
sudo ./rancher-save-images.sh --image-list ./rancher-images.txt
```
Результат: Docker начнет извлекаить (pulling) образы для установки с воздушным зазором. Будьте терпиливы. Этот процесс займет какое-то время. Когда процесс завершить будет сформирован файл __rancher-images.tar.gz__.

7. Добавте репозиторий Rancher Helm Chart

```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm fetch rancher-stable/rancher --version=v2.6.8
```

8. Получите render шаблона cert-manager (замените 192.168.0.10.sslip.io:5000 - на адрес вашего будущего registry, можете использовать для этого Jump Host)

```bash
export registry_url=192.168.0.10.sslip.io:5000
helm template cert-manager ./cert-manager-v1.7.1.tgz --output-dir . \
    --namespace cert-manager \
    --set image.repository=${registry_url}/quay.io/jetstack/cert-manager-controller \
    --set webhook.image.repository=${registry_url}/quay.io/jetstack/cert-manager-webhook \
    --set cainjector.image.repository=${registry_url}/quay.io/jetstack/cert-manager-cainjector \
    --set startupapicheck.image.repository=${registry_url}/quay.io/jetstack/cert-manager-ctl
```
9. Скачайте cert-manager CRD

```bash
curl -L -o cert-manager/cert-manager-crd.yaml https://github.com/jetstack/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml
```

10. Получите render шаблона Rancher
Вы можете использовать как самоподписные, так и собственные сертификаты для установки Rancher, ниже пример для самоподписных сертификатов.
Ниже в переменной __rancher_fqdn__ Вы должны указать FQDN для будущего сервера Rancher. А в переменной __registry_url__ URL вашего registry в безопасном сегменте (как например адрес и порт используемых в данной инструкции Jump Host, если у Вас нет готового registry)
```bash
export rancher_fqdn=192.168.0.11.sslip.io
export registry_url=192.168.0.10.sslip.io:5000
helm template rancher ./rancher-2.6.8.tgz --output-dir . \
    --no-hooks \
    --namespace cattle-system \
    --set hostname=${rancher_fqdn} \
    --set certmanager.version=1.7.1 \
    --set rancherImage=${registry_url}/rancher/rancher \
    --set systemDefaultRegistry=${registry_url} \
    --set replicas=1 \
    --set useBundledSystemChart=true \
    --version=2.6.8
```
11. Скачайте утилиты CLI 
```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
wget https://github.com/rancher/rke2/releases/download/v1.24.6%2Brke2r1/rke2.linux-amd64.tar.gz
```

12. Получите образы registry
```bash
 sudo docker pull httpd:2
 sudo docker save httpd:2 |  gzip --stdout > httpd.gz
 sudo docker pull registry:2
 sudo docker save registry:2 |  gzip --stdout > registry.gz
```
13. Сделайте копию всех полученных данных на внешний носитель, для копирования в сегмент без доступа в интернет:
- rancher-load-images.sh
- rancher-images.tar.gz
- rancher-images.txt
- ./rancher
- ./cert-manager
- kubectl
- rke2.linux-amd64.tar.gz
- httpd.gz
- registry.gz

## Установка и настройка систем в изолированном контуре
### Подготовка
- Скачайте установочный образ SUSE Linux Enterprise Server 15 SP4 (full ISO)
- Установите на Jump Host SUSE Linux Enterprise Server (оставьте подключенным к нему iso образ)
- При установке добавте следующие модули:
  - Containers Module
  - Server Applications Module
Перечисленные ниже комманды исходят из того, что у Вас нет доступа к службе SUSE RMT (централизованного обновления) внутри изолированного сегдмента. Если у Вас есть служба RMT, просто замените команды подключения репозиториев аналогичиными с использованием SUSEConnect. Централизванное обновление выходит за рамки данного вебинара, но наличие этой службы во многом упростит работы.
- 
### Создания образа SLES для VMware vSphere
1. На Jump Host установите пакет kiwi.
```bash
sudo zypper install -y python3-kiwi
```
2. Запустите комманду ниже для создания пароля пользователя root для образа
```bash
openssl passwd -1 -salt 'suse' suse1234
```
3. Копируйте каталог с настройками образа.
```bash
```
4. Скачайте и замените в каталоге скаченным файл [config.sh](config.sh)
5. Скачайте, замените скаченным и измените пароль в готовом шаблоне [Minimal.kiwi](Minimal.kiwi)
6. Скачайте SUSE Linux Enterprise Server 15SP4 (full iso) SLE-15-SP4-Full-x86_64-GM-Media1.iso
7. Создайте каталог __/media/suse__
```bash
sudo mkdir -p /media/suse
```
8. Подключите iso к каталогу.
```bash
sudo mount SLE-15-SP4-Full-x86_64-GM-Media1.iso /media/suse/
```
9. Запустите следующую команду, что-бы создать образ:
```bash
sudo kiwi-ng  --profile VMware system build --description ./kiwi-SLES-template/ --target-dir /tmp/out
```
Сохраните получившейся файл __SLES15-SP4-Minimal-Rancher.x86_64-15.4.0.vmdk__
10. Получившийся образ диска загрузить в хранилище VMware vSphere и использовать его для создание виртуальной машины используемой в дальнейшем как шаблон при развертывании.

### Утсноавите и настройте Docker
Если Вы установили SLES с DVD без подключения источников обновления и дополнительных модулей, то оставьте DVD в приводе (Важно, Вам нужен full ISO):
```bash
yast2 add-on
```
  Выберите Add => DVD => Подключите DVD образ => Отметьте "Containers Module" => Next => Accept => OK => Finish => OK
 
Для установки docker выполните:
```bash
zypper in -y docker
usermod -aG docker sles
usermod -aG docker root
sudo systemctl enable --now docker
chown root:docker /var/run/docker.sock
```

### Cloud Init 
В приведенном cloud-init добавленны следующие настройки:
chronyd

[Файлы материалов](https://github.com/ppzhukov/airgap-10.2022/)

