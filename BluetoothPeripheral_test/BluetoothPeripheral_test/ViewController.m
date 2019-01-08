//
//  ViewController.m
//  BluetoothPeripheral_test
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

@interface ViewController ()<CBPeripheralManagerDelegate, UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UILabel *messageLb;
@property (weak, nonatomic) IBOutlet UITextField *sendMessageTF;

//周边设备管理
@property (nonatomic, strong) CBPeripheralManager *peripheralManager;

//连接的中心设备
@property (nonatomic, strong) NSMutableArray *subscribedCentrals;

//自定义服务
@property (nonatomic, strong) CBMutableService *customService;

//自定义特征
@property (nonatomic, strong) CBMutableCharacteristic *customCharacteristic;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.peripheralManager = [[CBPeripheralManager alloc]initWithDelegate:self queue:nil];
    
    self.subscribedCentrals = [NSMutableArray array];
    
    self.sendMessageTF.delegate = self;
    
    
}


- (IBAction)onClickSendMessageBtn:(UIButton *)sender
{
    
    NSData *data = [_sendMessageTF.text dataUsingEncoding:NSUTF8StringEncoding];
    
    NSLog(@"data===%@", data);
    
    [_peripheralManager updateValue:data forCharacteristic:_customCharacteristic onSubscribedCentrals:_subscribedCentrals];
    
}

#pragma mark - CBPeripheralManagerDelegate
//周边设备状态改变
-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
            NSLog(@"服务已开启");
            //添加服务到周边
            [self addServerForPeripheral];
            
            break;
            
        case CBPeripheralManagerStatePoweredOff:
            NSLog(@"服务已关闭");
            break;
            
        case CBPeripheralManagerStateResetting:
            NSLog(@"正在重置");
            break;
            
        case CBPeripheralManagerStateUnsupported:
            NSLog(@"未支持");
            break;
            
        case CBPeripheralManagerStateUnauthorized:
            NSLog(@"未授权");
            break;
            
        default:
            break;
    }
}

#pragma mark - 添加服务
- (void)addServerForPeripheral
{
   CBUUID *characteristicUUID = [CBUUID UUIDWithString:SRCharacteristicUUID];
    
    
//    NSData *characteristicValue = [_sendMessageTF.text dataUsingEncoding:NSUTF8StringEncoding];
    
    self.customCharacteristic = [[CBMutableCharacteristic alloc] initWithType:characteristicUUID properties:CBCharacteristicPropertyNotify|CBCharacteristicPropertyRead | CBCharacteristicPropertyWriteWithoutResponse value:nil permissions:CBAttributePermissionsReadable|CBAttributePermissionsWriteable];
    
    
     CBUUID *serviceUUID = [CBUUID UUIDWithString:SRServiceUUID];
    
    self.customService = [[CBMutableService alloc] initWithType:serviceUUID primary:YES];
    
    
    [_customService setCharacteristics:@[_customCharacteristic]];
    
    [_peripheralManager addService:_customService];
    
    
}

#pragma mark - 添加服务完成
- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error)
    {
        NSLog(@"添加服务error=%@", error);
        
    }else
    {
       //开始广播服务
        [_peripheralManager startAdvertising:@{CBAdvertisementDataLocalNameKey:@"SRServer", CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:SRServiceUUID]]}];
        
        
    }
}


#pragma mark - 开始广播服务完成
- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    if (error)
    {
        NSLog(@"广播服务error=%@", error);
        
    }else
    {
        NSLog(@"开始广播服务完成");
    }
}


#pragma mark - 当连接的Central端请求读取特性的值时
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    if ([request.characteristic.UUID isEqual:_customCharacteristic.UUID])
    {
        NSLog(@"request.offset==%ld --- %ld",request.offset, self.customCharacteristic.value.length);
        
        // 确保读请求所请求的偏移量没有超出我们的特性的值的长度范围
        // offset属性指定的请求所要读取值的偏移位置
        if (request.offset > self.customCharacteristic.value.length)
        {
            // 对请求作出失败响应
            [_peripheralManager respondToRequest:request withResult:CBATTErrorInvalidOffset];
            return;

        }else
        {
            request.value = [self.customCharacteristic.value subdataWithRange:NSMakeRange(request.offset, self.customCharacteristic.value.length - request.offset)];

            // 对请求作出成功响应
            [_peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
        }

    }
}


#pragma mark - 当连接的Central端请求写入特性的值时
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests
{
    for (CBATTRequest *request in requests)
    {
        //传递过来的值
        NSString *value = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
        
        _messageLb.text = value;
        
        NSLog(@"request.value==%@", request.value);
        
    }
}


#pragma mark - 已经订阅到特征
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    if ([characteristic isEqual:_customCharacteristic])
    {
        //添加中心
        [_subscribedCentrals addObject:central];
        
    }
}


#pragma mark - 已经从特征中取消订阅
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    if ([characteristic isEqual:_customCharacteristic])
    {
        [_subscribedCentrals removeObject:central];
    }
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
