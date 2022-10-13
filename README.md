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
    subgraph d30 ["Выделенный сегмент сети"]
      id3([SUSE Rancher Nodes])
      id4([RKE2 Nodes])
    end
  end
```
В тестовом варианте мы можем совместить ряд ролей (Например Registry и Jump Host, роли серверов Kubernetes)
В нашем вебинаре мы будем ипользовать следующий стек продуктов и роли.
1. Сервер с доступом в интенет на базе SUSE Linux Enterprise Server.
2. Конфигурационные файлы Terraform, которые создадут нам Template для узлов в VMware vSphere, а также преднастроенные узлы и сетевой сегмент для развертывание.  
3. Jump Host, с помощью которого будет производиться настройка узлов сети с использование Salt и на котором будет размещен Docker Registry также на этом сервере будет настроен [sslip.io](https://github.com/cunnie/sslip.io) для реализации простого DNS доступа.
4. Один узел для развертывания Rancher (Будет создан Terrafor и настроенны с помощью Salt).
5. Три узла для развертывания управляемого кластера (будут созданны Racnher, добавленны в управление Salt, донастроенны cloud-init).

### Аппаратные требования
* 1x Jump Host
  4 vCPU
  16 GiB RAM
  1 x HDD +300GB (для registry)
  Поскольку мы совместили роли, нам понадобиться больше места: хранить копию данных образов для загрузки, копию данных образов в Docker, копию данных образов в Registry.

* 1x dedicate server for Rancher
  4 vCPU
  16 GiB RAM
  1 x HDD - > 100 GB

* 3x RKE2 Node - role: ETCD, Controls Plane, Worker
  16 vCPU
  64 GiB RAM
  1 x HDD - > 320 GB
  Поскольку мы совместили роли, нам понадобиться больше ресурсов для запуска реальной нагрузки.

### Используемые версии
* RKE2 v1.25.2+rke2r1
* Rancher v2.6.8
* SLES 15 SP4
* Helm v3
* Longhorn v1.2

## Установка и настройка сервера с доступом в интернет
На данном сервере Вам потребуется Linux с установленным Docker. Я рекомендую установить SUSE Linux Enterprise Server в базовой конфигурации (Это может быть вариант Minimal для которого можно использовать следующую [инструкцию](front_server-install_script.md)).
Вы можете установить все обновления SUSE Linux Enterprise Server, для этого Вам потребуется ключ активации, возможно также использование триального ключа.
Вы также можете использовать OpenSUSE заменив ряд команд.
И так, если Вы установили SUSE Linux Enterprise Server, Вам потребуется сделать следющее:
1. Установить и запустить Docker
```bash
SUSEConnect -p sle-module-containers/15.3/x86_64
zypper in -y docker
usermod -aG docker sles
usermod -aG docker root
chown root:docker /var/run/docker.sock
```
2. Установка CLI helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```


[Файлы материалов](https://github.com/ppzhukov/airgap-10.2022/)

