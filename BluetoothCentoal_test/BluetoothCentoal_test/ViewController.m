//
//  ViewController.m
//  BluetoothCentoal_test
//
//  Created by wcg on 16/12/9.
//  Copyright © 2016年 MZYW. All rights reserved.
//

#import "ViewController.h"

#import <CoreBluetooth/CoreBluetooth.h>


//服务的UUID
#define SRServiceUUID @"C4FB2349-72FE-4CA2-94D6-1F3CB16331EE"

//特征的UUID
#define SRCharacteristicUUID @"6A3E4B28-522D-4B3B-82A9-D5E2004534FC"


@interface ViewController ()<CBCentralManagerDelegate, CBPeripheralDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *messageLb;

@property (weak, nonatomic) IBOutlet UITextField *sendMessageTF;


//中心设备管理器
@property (nonatomic, strong) CBCentralManager *centralManager;


//连接的外围设备
@property (strong,nonatomic) NSMutableArray *peripherals;


//当前连接的设备
@property (nonatomic, strong) CBPeripheral *currentConnectItem;

//当前连接的设备特征
@property (nonatomic, strong) CBCharacteristic *currentItemCharacter;



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //创建中心角色
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    self.peripherals = [NSMutableArray array];
    
    self.sendMessageTF.delegate = self;
    
    
}

#pragma mark - CBCentralManager代理方法
//中心状态改变
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            
            NSLog(@"服务已开启");
            
            //扫描外界设备
            [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SRServiceUUID]]  options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
            
            break;
            
        case CBCentralManagerStatePoweredOff:
            NSLog(@"服务已关闭");
            break;
            
        case CBCentralManagerStateResetting:
            NSLog(@"正在重置");
            break;
            
        case CBCentralManagerStateUnsupported:
            NSLog(@"未支持");
            break;
            
        case CBCentralManagerStateUnauthorized:
            NSLog(@"未授权");
            break;
            
        default:
            break;
    }
    
}


#pragma mark - 中心已发现外围设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"扫描设备成功！");
    
    //先停止扫描
    [_centralManager stopScan];
    
    //赋值当前连接的设备
    if (self.currentConnectItem != peripheral)
    {
        self.currentConnectItem = peripheral;
        
    }
    
    //开始连接外界设备
    [_centralManager connectPeripheral:_currentConnectItem options:nil];
    
}


#pragma mark - 中心连接外界设备成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"连接设备成功！");
    
    _currentConnectItem.delegate = self;
    
    //外界设备开始查找服务
    [_currentConnectItem discoverServices:@[[CBUUID UUIDWithString:SRServiceUUID]]];
    
}


#pragma mark - 中心连接外界设备失败
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (error) {
        NSLog(@"连接外界设备失败==%@", error);
    }
    
}



//CBPeripheralDelegate代理方法
#pragma mark - 外界设备发现了服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services)
    {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:SRServiceUUID]])
        {
            //外界设备开始查找特征
            [_currentConnectItem discoverCharacteristics:
             @[[CBUUID UUIDWithString:
                SRCharacteristicUUID]] forService:service];
            
        }
    }
}


#pragma mark - 外界设备发现了特征
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
   
    if ([service.UUID isEqual:[CBUUID UUIDWithString:
                               SRServiceUUID]])
    {
        for (CBCharacteristic *characteristic in
             service.characteristics)
        {
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:SRCharacteristicUUID]])
            {
                //赋值
                 _currentItemCharacter = characteristic;
                
                //
                [_currentConnectItem setNotifyValue:YES forCharacteristic:characteristic];
                
            }
        }
    }

}


#pragma mark - 特征通知状态的改变
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:SRCharacteristicUUID]])
    {
        return;
    }
    
    if (characteristic.isNotifying)
    {
        //正在通知，读取特征数据
        [_currentConnectItem readValueForCharacteristic:characteristic];
        
    }else
    {
        //通知停止，取消连接
        [_centralManager cancelPeripheralConnection:_currentConnectItem];
        
    }
    
}


#pragma mark - 特征的值的改变
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSData *data = characteristic.value;
    
    NSString *messageStr = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    
    _messageLb.text = messageStr;
    
    NSLog(@"characteristic.value==%@", data);
}



- (IBAction)sendMessageBtn:(UIButton *)sender
{
    NSData *data = [_sendMessageTF.text dataUsingEncoding:NSUTF8StringEncoding];
    
    [_currentConnectItem writeValue:data forCharacteristic:_currentItemCharacter type:CBCharacteristicWriteWithoutResponse];
    
    [_sendMessageTF resignFirstResponder];
    
    
}



- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    return YES;
    
}















- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
