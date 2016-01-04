#!/bin/bash

##############################################################################
#                                                                            # 
# Shell program to install PostgreSQL Database server via source code.       #
#                                                                            #
# Revisions:                                                                 # 
#                                                                            #
# 2015-12-23	File created.                                                                            # 
#                                                                            #
##############################################################################

LICENSE='
This software is licensed under the New BSD Licence.
******************************************************************************
Copyright (c) 2015, Juliano Atanazio - juliano777@gmail.com
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

-        Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

-        Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

-        Neither the name of the Juliano Atanazio nor the names of its
    contributors may be used to endorse or promote products derived from this
    software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
******************************************************************************
'

#==============================================================================
# AJUSTES INICIAIS
#==============================================================================

# Detectar SystemD
if (command -v systemctl > /dev/null); then
    SYSTEMD=true
else
    SYSTEMD=false
fi

# Criar grupo de sistema postgres:
groupadd -r postgres &> /dev/null

# Criar usuário de sistema postgres:
useradd -s /bin/bash -k /etc/skel -d /var/lib/pgsql \
-g postgres -m -r postgres  &> /dev/null

# Quantidade de argumentos
N_ARGS=`echo ${#}`

# Mensagem com as variáveis de instalação
MSG="
******************************************************************************
Variáveis de Instalação
******************************************************************************

DISTRO_FAMILY (Obrigatória)

	Aque família de distribuição pertence:

	1) Debian
	2) RedHat
 
PGVERSIONXYZ (Obrigatória)
	
	A versão completa do PostgreSQL (X.Y.Z)		

PG_INSTALL_DIR

	Diretório de instalação do PostgreSQL.

PGDATA
	
	Diretório de dados.

Q_PGXLOG

	Variável sobre o questionamento se o diretório de logs de
transação (xlogs) deverão ficar fora do PGDATA (s) ou não (n; padrão).	

PG_XLOG

	Diretório de logs de transação.

PG_STATS_TEMP

	Diretório de estatísticas temporárias para ponto de montagem como RAMDisk.

PG_STATS_TEMP_SIZE

	Tamanho do RAMDisk para estatísticas temporárias.

******************************************************************************
"


# Verificação de parâmetros
if [ ${N_ARGS} -eq 0 ]; then
    # Fazer nada
    true
elif [ ${N_ARGS} -eq 1 ]; then
    case ${1} in
        '--help')
            echo "${0} [--help | --vars | arquivo_de_variaveis]"
            exit 0
            ;;

        '--vars')
            echo "${MSG}"
            exit 0
            ;;

        '--license')
            echo "${LICENSE}"
            exit 0
            ;;

        *)
                # Ler o arquivo de configuração
                source ${1} 
            ;;
    esac

else
    echo 'Erro: Quantidade errada de argumentos!'
    exit 1
fi

# Limpa a tela
clear 	

# Menu Inicial
echo -e "\
#============================================================================#
# Scrip de instalação automática do PostgreSQL via código-fonte              #
#                                                                            #
# Por: Juliano Atanazio                                                      # 
#============================================================================#
"



#==============================================================================
# FAMÍLIA DE DISTRO
#==============================================================================

MSG_DISTRO="
Escolha em que distro Linux está baseada a instalação:

1) Debian: Ubuntu, LinuxMint...
2) RedHat: CentOS, Scientific Linux, Oracle Linux, Fedora...

==============================================================================
"

# Variável para o tipo de distro: DISTRO_FAMILY
if [ -z ${DISTRO_FAMILY} ]; then
    echo -e "${MSG_DISTRO}"
    read DISTRO_FAMILY 
fi

MSG_DISTRO='Foi escolhida uma distro da família'

# Uso de case para dar a mensagem completa
case ${DISTRO_FAMILY} in
    "1")
        echo "${MSG_DISTRO} Debian!";   
    ;;

    "2")
        echo "${MSG_DISTRO} RedHat!";   
    ;;

    *)
       echo 'Escolha "1" ou "2"!';
       exit 1
    ;;
esac



#==============================================================================
# QUAL VERSÃO DO POSTGRESQL?
#==============================================================================


while [ -z ${PGVERSIONXYZ} ]; do
    # Versão minoritária (X.Y.Z) do PostgreSQL (PGVERSIONXYZ):
    read -p \
    'Digite o número de versão completo (X.Y.Z) do PostgreSQL a ser baixado: ' \
    PGVERSIONXYZ    
done


# Baixando o código-fonte silenciosamente e em background
(wget --quiet -c \
ftp://ftp.postgresql.org/pub/source/v${PGVERSIONXYZ}/\
postgresql-${PGVERSIONXYZ}.tar.bz2 -P /tmp/) &

# Versão majoritária (X.Y) do PostgreSQL
PGVERSION=`echo ${PGVERSIONXYZ} | cut -f1-2 -d.`

#==============================================================================
# PARÂMETROS DE INSTALAÇÃO
#==============================================================================


# Local de Instalação:
PG_INSTALL_DIR_TMP="/usr/local/pgsql/${PGVERSION}"

# Verificação de variável vazia
if [ -z ${PG_INSTALL_DIR} ]; then
    read -p \
    "Diretório de instalação (padrão ${PG_INSTALL_DIR_TMP}): " \
    PG_INSTALL_DIR

    if [ -z ${PG_INSTALL_DIR} ]; then 
        PG_INSTALL_DIR=${PG_INSTALL_DIR_TMP};
    fi    
fi

# Diretório de binários
PGBIN="${PG_INSTALL_DIR}/bin"	

# Diretório de bibliotecas
PG_LD_LIBRARY_PATH="${PG_INSTALL_DIR}/lib"	

# Diretório de manuais
PG_MANPATH="${PG_INSTALL_DIR}/man"

# Diretório de arquivos de configuração
PGCONF="/etc/pgsql/${PGVERSION}"	

# Diretório de arquivos de log
PGLOG="/var/log/pgsql/${PGVERSION}"	


# Diretório de dados (variável temporária):
PGDATA_TMP="/var/lib/pgsql/${PGVERSION}/data"

# Verificação de variável vazia
if [ -z ${PGDATA} ]; then
    # Ler variável PGDATA informada pelo usuário
    read -p \
    "Diretório de dados, o PGDATA (padrão ${PGDATA_TMP}): " \
    PGDATA

    # Se nada for informado, atribuir à variável desejada o valor da
    # variável temporária
    if [ -z ${PGDATA} ]; then 
        PGDATA=${PGDATA_TMP};
    fi    
fi


# Variável de ambiente "booleana" para dizer se os logs de transação
# estarão dentro de PGDATA:
Q_PGXLOG_TMP='n'

# Verificação de variável vazia
if [ -z ${Q_PGXLOG} ]; then
    # Usuário informa se (S) o diretório de logs de transação será
    # dentro de PGDATA ou não (N):
    read -p \
    "O diretório de logs de transação será fora de PGDATA? [S/(N)]: " \
    Q_PGXLOG

    # Se nada for informado, atribuir à variável desejada o valor da
    # variável temporária
    if [ -z ${Q_PGXLOG} ]; then
        Q_PGXLOG=${Q_PGXLOG_TMP};
    fi
fi

# Tratando a resposta de forma a deixar como letra minúscula:
Q_PGXLOG=`echo ${Q_PGXLOG:0:1} | awk '{print tolower($0)}'`

# Opções iniciais do initdb (com pg_xlog dentro de PGDATA):
INITDB_OPTS="-D ${PGDATA} -E utf8 -U postgres \
--locale=pt_BR.utf8 \
--lc-collate=pt_BR.utf8 \
--lc-monetary=pt_BR.utf8 \
--lc-messages=en_US.utf8 \
-T portuguese"


# Se o pg_xlog for fora de PGDATA:
if [ ${Q_PGXLOG} = 's' ]; then  
    if [ -z ${PG_XLOG} ]; then
        # Informar qual é a localização dos logs de transação:
        read -p \
        "Diretório de xlogs: " \
        PG_XLOG

    fi

    # Opções de initdb incluindo o diretório de logs de transação    
    INITDB_OPTS="${INITDB_OPTS} -X ${PG_XLOG}"
fi


# Diretório de arquivos de estatísticas temporárias:
PG_STATS_TEMP_TMP="${PGDATA}/pg_stat_tmp"

# Verificação de variável vazia
if [ -z ${PG_STATS_TEMP} ]; then
    # Usuário informa o diretório de estatísticas temporárias
    read -p \
    "Diretório de estatísticas temporárias (padrão ${PG_STATS_TEMP_TMP}): " \
    PG_STATS_TEMP

    # Se nada for informado, atribuir à variável desejada o valor da
    # variável temporária
    if [ -z ${PG_STATS_TEMP} ]; then 
        PG_STATS_TEMP=${PG_STATS_TEMP_TMP};
    fi
fi



# Tamanho padrão do ponto de montagem em RAM para estatísticas temporárias:
PG_STATS_TEMP_SIZE_TMP='32M'

# Verificação de variável vazia
if [ -z ${PG_STATS_TEMP_SIZE} ]; then
    # Usuário informa o tamanho em RAM como ponto de montagem par estatísticas
    # temporárias:
    read -p \
    "Tamanho em RAM o diretório de estatísticas temporárias \
    (padrão 32M): " PG_STATS_TEMP_SIZE

    # Se nada for informado, atribuir à variável desejada o valor da
    # variável temporária
    if [ -z ${PG_STATS_TEMP_SIZE} ]; then 
        PG_STATS_TEMP_SIZE=${PG_STATS_TEMP_SIZE_TMP};
    fi
fi


# Montagem da linha para montagem em memória RAM
echo -e "\ntmpfs ${PG_STATS_TEMP} tmpfs \
size=${PG_STATS_TEMP_SIZE},uid=postgres,gid=postgres 0 0" >> /etc/fstab

#==============================================================================
# PACOTES
#==============================================================================

# Pacotes comuns
PKG='bison gcc flex gettext make'

# Pacotes Debian
PKG_DEB='libreadline-dev libssl-dev libxml2-dev libldap2-dev libperl-dev python-dev chkconfig'

# Pacotes RedHat
PKG_RH='readline-devel openssl-devel libxml2-devel openldap-devel perl-devel python-devel perl-ExtUtils-MakeMaker perl-ExtUtils-Embed'

# Conforme o tipo de distro utilizar os respectivos pacotes para instalação
if [ ${DISTRO_FAMILY} = '1' ]; then
    PKG="${PKG} ${PKG_DEB}"
    aptitude -y install ${PKG}
else
    PKG="${PKG} ${PKG_RH}"
    yum -y install ${PKG}
fi

# Criação de diretórios
mkdir -p ${PG_INSTALL_DIR}/src/ ${PGCONF} ${PGLOG} ${PG_XLOG} ${PGDATA}

# Mover o código-fonte baixado para o sub-diretório src no diretório de
# instalação:
mv /tmp/postgresql-${PGVERSIONXYZ}.tar.bz2 ${PG_INSTALL_DIR}/src/

# Descompactar o código-fonte
tar xf ${PG_INSTALL_DIR}/src/postgresql-${PGVERSIONXYZ}.tar.bz2 -C ${PG_INSTALL_DIR}/src/ 

#==============================================================================
# VARIÁVEIS DE AMBIENTE PARA COMPILAÇÃO
#==============================================================================

# Protege o processo principal do OOM Killer
CPPFLAGS="-DLINUX_OOM_SCORE_ADJ=0"

# Número de jobs conforme a quantidade cores de CPU (cores + 1): 
NJOBS=`expr \`cat /proc/cpuinfo | egrep ^processor | wc -l\` + 1`

# Opções do make
MAKEOPTS="-j${NJOBS}"

# Tipo de hardware
CHOST="x86_64-unknown-linux-gnu"

# Flags de otimização para o make 
CFLAGS="-march=native -O2 -pipe"
CXXFLAGS="$CFLAGS"


#=============================================================================

# Opções do configure
CONFIGURE_OPTS="
--prefix=${PG_INSTALL_DIR} \
--with-perl \
--with-python \
--with-libxml \
--with-openssl \
--with-ldap \
--mandir=/usr/local/pgsql/${PGVERSION}/man \
--docdir=/usr/local/pgsql/${PGVERSION}/doc"

# Ir ao diretório onde estão os fontes:
cd ${PG_INSTALL_DIR}/src/postgresql-${PGVERSIONXYZ}

# Processo de configure
./configure ${CONFIGURE_OPTS}

# Compilação (com manuais e contrib):
make world 

# Instalação
make install-world

# Criar o arquivo .pgvars com seu respectivo conteúdo no diretório do usuário home postgres:
cat << EOF > ~postgres/.pgvars

# Environment Variables

export PGVERSION='${PGVERSION}'
export LD_LIBRARY_PATH="${PG_LD_LIBRARY_PATH}:\${LD_LIBRARY_PATH}" 
export MANPATH="${PG_MANPATH}:\${MANPATH}"
export PATH="${PGBIN}:\${PATH}"
export PGDATA="${PGDATA}"
export PGCONF="${PGCONF}"
EOF


#==============================================================================
# SISTEMA DE INICIALIZAÇÃO
#==============================================================================

# Definição do arquivo de serviço para SystemD
SYSTEMD_FILE="
[Unit]
Description=PostgreSQL ${PGVERSION} database server
After=syslog.target
After=network.target
[Service]
Type=forking
User=postgres
Group=postgres
Environment=PGDATA=${PGDATA}
OOMScoreAdjust=-1000    
ExecStart=${PGBIN}/pg_ctl start -D ${PGDATA} -s -w -t 300
ExecStop=${PGBIN}/pg_ctl stop -D ${PGDATA} -s -m fast
ExecReload=${PGBIN}/pg_ctl reload -D ${PGDATA} -s
TimeoutSec=300
[Install]
WantedBy=multi-user.target
"

# Tomada de decisão se for SystemD ou não
if ${SYSTEMD}; then
    # Criação do arquivo de serviço
    echo "${SYSTEMD_FILE}" > /lib/systemd/system/postgresql-${PGVERSION}.service

    # Habilita o serviço na inicialização
    systemctl enable postgresql-${PGVERSION}.service
else
    # Copiar o script de inicialização para o diretório /etc/init.d:
    cp contrib/start-scripts/linux /etc/init.d/postgresql-${PGVERSION}

    # Dá permissão de execução ao script:
    chmod +x /etc/init.d/postgresql-${PGVERSION}

    # Adiciona o script para a inicialização:
    chkconfig --add  postgresql-${PGVERSION}

    #==============================================================================
    # ALTERAÇÕES NO SCRIPT DE INICIALIZAÇÃO
    #==============================================================================

    # Alterar prefix
    sed "s:\(^prefix.*\):#\1\nprefix='${PG_INSTALL_DIR}':g" -i /etc/init.d/postgresql-${PGVERSION}

    # Adicionar PGBIN logo depois de prefix
    sed "s:\(^prefix.*\):\1\n\n#Directory for binaries\nPGBIN='${PGBIN}':g" \
    -i /etc/init.d/postgresql-${PGVERSION}

    # PGDATA
    sed "s:\(^PGDATA.*\):#\1\nPGDATA='${PGDATA}':g" \
    -i /etc/init.d/postgresql-${PGVERSION}

    # Alterar PGUSER
    sed "s:^PGUSER.*:PGUSER='postgres':g" \
    -i /etc/init.d/postgresql-${PGVERSION}

    # Alterar PGLOG
    sed "s:\(^PGLOG.*\):#\1\nPGLOG=\"${PGLOG}/serverlog\":g" \
    -i /etc/init.d/postgresql-${PGVERSION}

    # Alterar PATH
    sed 's;\(^PATH.*\);#\1\nPATH=\"\${PGBIN}:\${PATH}\";g' \
    -i /etc/init.d/postgresql-${PGVERSION}

    # Alterar DAEMON
    sed 's:\(^DAEMON.*\):#\1\nDAEMON="\${PGBIN}/postgres":g' \
    -i /etc/init.d/postgresql-${PGVERSION}

    # Alterar PGCTL
    sed 's:\(^PGCTL.*\):#\1\nPGCTL="\${PGBIN}/pg_ctl":g' \
    -i /etc/init.d/postgresql-${PGVERSION}
fi


#==============================================================================
# Limpeza de pacotes, definições de usuário, criação de cluster e permissões
#==============================================================================


# Conforme o tipo de distro limpar os pacotes instalados e definir 
# como o usuário postgres vai ler o arquivo de variáveis de ambiente
if [ ${DISTRO_FAMILY} = '1' ]; then    
    aptitude clean
    aptitude -y purge ${PKG}
    echo -e "\nsource ~/.pgvars" >> ~postgres/.profile 
else
    yum clean all
    yum -y erase ${PKG}
    echo -e "\nsource ~/.pgvars" >> ~postgres/.bash_profile 	
fi


# Dar propriedade a usuário e grupo postgres aos diretórios
chown -R postgres: ${PGCONF} ${PGLOG} ${PG_XLOG} ${PGDATA} ~postgres

# Criação de cluster
su - postgres -c "initdb ${INITDB_OPTS}"

# Mover arquivos de configuração para o diretório de configuração
su - postgres -c "mv ${PGDATA}/*.conf ${PGCONF}/"

# Criar link para cada configuração no diretório de dados
su - postgres -c "ls ${PGCONF}/* | xargs -i ln -sf {} ${PGDATA}/"

# Criar diretório de estatísticas temporárias
mkdir ${PG_STATS_TEMP}

# Dar propriedade a usuário e grupo postgres
chown -R postgres: ${PG_STATS_TEMP}


#==============================================================================
# ALTERAÇÕES NO postgresql.conf
#==============================================================================

# listen_addresses = '*'
sed "s:\(^#listen_addresses.*\):\1\nlisten_addresses = '*':g" -i ${PGCONF}/postgresql.conf

# log_destination = 'stderr'
sed "s:\(^#log_destination.*\):\1\nlog_destination = 'stderr':g" -i ${PGCONF}/postgresql.conf

# logging_collector = on
sed "s:\(^#logging_collector.*\):\1\nlogging_collector = on:g" -i ${PGCONF}/postgresql.conf

# log_filename (nova linha descomentada)
sed "s:\(^#\)\(log_filename.*\):\1\2\n\2:g" -i ${PGCONF}/postgresql.conf

# log_directory = '${PGLOG}'
sed "s:\(^#log_directory.*\):\1\nlog_directory = '${PGLOG}':g" -i ${PGCONF}/postgresql.conf

# stats_temp_directory = '${PG_STATS_TEMP}'
sed "s:\(^#stats_temp_directory.*\):\1\nstats_temp_directory = '${PG_STATS_TEMP}':g" -i ${PGCONF}/postgresql.conf


#==============================================================================
# MONTAGEM DE FILESYSTEMS E INICIAR SERVIÇO
#==============================================================================

# Monta tudo definido em /etc/fstab
mount -a

# Inicia o serviço conforme o sistema de inicialização
if ${SYSTEMD}; then    
    systemctl start postgresql-${PGVERSION}
else
    service postgresql-${PGVERSION} start
fi

#==============================================================================
