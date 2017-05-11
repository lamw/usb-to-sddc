#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Setup vSAN Cluster as Storage cmdlets haven't been ported to PowerCLI Core
* Create vSphere Datacenter
* Create vSphere Cluster: Enable DRS/vSAN
* Enable Dedupe/Compression on vSAN Cluster
"""

__author__ = 'William Lam'
from pyVmomi import vim
from pyVim.connect import SmartConnect, Disconnect
from requests.packages.urllib3.exceptions import InsecureRequestWarning

import atexit
import argparse
import getpass
import requests
import sys
import ssl
#import the VSAN API python bindings
import vsanmgmtObjects
import vsanapiutils

def GetArgs():
   """
   Supports the command-line arguments listed below.
   """
   parser = argparse.ArgumentParser(
       description='Process args for VSAN SDK sample application')
   parser.add_argument('-s', '--host', required=True, action='store',
                       help='Remote host to connect to')
   parser.add_argument('-o', '--port', type=int, default=443, action='store',
                       help='Port to connect on')
   parser.add_argument('-u', '--user', required=True, action='store',
                       help='User name to use when connecting to host')
   parser.add_argument('-p', '--password', required=False, action='store',
                       help='Password to use when connecting to host')
   parser.add_argument('-d', '--datacenter', required=True, dest='datacenterName',
                      default='Datacenter')
   parser.add_argument('-c', '--cluster', required=True, dest='clusterName',
                      default='VSAN-Cluster')
   args = parser.parse_args()
   return args

def get_obj(content, vimtype, name, folder=None):
    obj = None
    if not folder:
        folder = content.rootFolder
    container = content.viewManager.CreateContainerView(folder, vimtype, True)
    for item in container.view:
        if item.name == name:
            obj = item
            break
    return obj

#Start program
def main():
   args = GetArgs()
   if args.password:
      password = args.password
   else:
      password = getpass.getpass(prompt='Enter password for host %s and '
                                        'user %s: ' % (args.host,args.user))

   #For python 2.7.9 and later, the defaul SSL conext has more strict
   #connection handshaking rule. We may need turn of the hostname checking
   #and client side cert verification
   context = None
   if sys.version_info[:3] > (2,7,8):
      context = ssl.create_default_context()
      context.check_hostname = False
      context.verify_mode = ssl.CERT_NONE

   # Disabling the annoying InsecureRequestWarning message
   requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

   si = SmartConnect(host=args.host,
                     user=args.user,
                     pwd=password,
                     port=int(args.port),
                     sslContext=context)

   atexit.register(Disconnect, si)

   #for detecting whether the host is VC or ESXi
   aboutInfo = si.content.about

   if aboutInfo.apiType == 'VirtualCenter':
      majorApiVersion = aboutInfo.apiVersion.split('.')[0]
      if int(majorApiVersion) < 6:
         print('The Virtual Center with version %s (lower than 6.0) is not supported.'
               % aboutInfo.apiVersion)
         return -1

      # Create vSphere Datacenter
      folder = si.content.rootFolder

      dc_moref = get_obj(si.content, [vim.Datacenter], args.datacenterName)
      if not dc_moref:
         print("Creating vSphere Datacenter: %s" % args.datacenterName)
         dc_moref = folder.CreateDatacenter(name=args.datacenterName)

      # Create vSphere Cluster
      host_folder = dc_moref.hostFolder
      cluster_spec = vim.cluster.ConfigSpecEx()
      drs_config = vim.cluster.DrsConfigInfo()
      drs_config.enabled = True
      cluster_spec.drsConfig = drs_config
      vsan_config = vim.vsan.cluster.ConfigInfo()
      vsan_config.enabled = True
      cluster_spec.vsanConfig = vsan_config
      print("Creating vSphere Cluster: %s" % args.clusterName)
      cluster = host_folder.CreateClusterEx(name=args.clusterName, spec=cluster_spec)

      #Here is an example of how to access VC side VSAN Health Service API
      vcMos = vsanapiutils.GetVsanVcMos(si._stub, context=context)

      # Get VSAN Cluster Config System
      vccs = vcMos['vsan-cluster-config-system']

      #cluster = getClusterInstance(args.clusterName, si)

      if cluster is None:
         print("Cluster %s is not found for %s" % (args.clusterName, args.host))
         return -1

      vsanCluster = vccs.VsanClusterGetConfig(cluster=cluster)

      # Check to see if Dedupe & Compression is already enabled, if not, then we'll enable it
      if(vsanCluster.dataEfficiencyConfig.compressionEnabled == False or vsanCluster.dataEfficiencyConfig.dedupEnabled == False):
          print ("Enabling Compression/Dedupe capability on vSphere Cluster: %s" % args.clusterName)
          # Create new VSAN Reconfig Spec, both Compression/Dedupe must be enabled together
          vsanSpec = vim.VimVsanReconfigSpec(
             dataEfficiencyConfig=vim.VsanDataEfficiencyConfig(
                compressionEnabled=True,
                dedupEnabled=True
             ),
             modify=True
          )
          vsanTask = vccs.VsanClusterReconfig(cluster=cluster,vsanReconfigSpec=vsanSpec)
          vcTask = vsanapiutils.ConvertVsanTaskToVcTask(vsanTask,si._stub)
          vsanapiutils.WaitForTasks([vcTask],si)
      else:
        print ("Compression/Dedupe is already enabled on vSphere Cluster: %s" % args.clusterName)

# Start program
if __name__ == "__main__":
   main()
