#include <fastrtps/xmlparser/XMLProfileManager.h>
#include <iostream>
int main() {
    if (eprosima::fastrtps::xmlparser::XMLP_ret::XML_OK == 
        eprosima::fastrtps::xmlparser::XMLProfileManager::loadXMLFile("config/fastdds_shm.xml")) {
        std::cout << "XML Parsed successfully" << std::endl;
        return 0;
    }
    std::cout << "XML Parse failed" << std::endl;
    return 1;
}
